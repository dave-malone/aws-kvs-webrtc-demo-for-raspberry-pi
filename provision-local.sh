#!/bin/bash
#
# provision-local.sh
#
# Runs from your local machine (laptop/desktop). Provisions AWS IoT resources
# using your local AWS credentials (SSO or otherwise), then deploys certs and
# the SDK build to a Raspberry Pi over SSH.
#
# Usage:
#   ./provision-local.sh --profile <aws-profile> --pi-host <user@host> --thing-name <name>
#
# Prerequisites:
#   - AWS CLI v2 installed locally
#   - An active AWS session (e.g. `aws sso login --profile <profile>`)
#   - SSH key-based access to the Raspberry Pi
#

set -euo pipefail

# ─── Prerequisites check ─────────────────────────────────────────────────────

MISSING=()
for cmd in aws jq ssh scp curl; do
  if ! command -v "$cmd" &>/dev/null; then
    MISSING+=("$cmd")
  fi
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo "Error: The following required tools are not installed: ${MISSING[*]}"
  echo ""
  echo "Install them before running this script:"
  echo "  macOS:  brew install ${MISSING[*]}"
  echo "  Linux:  sudo apt-get install -y ${MISSING[*]}"
  exit 1
fi

# Verify AWS CLI is v2 (needed for SSO support)
AWS_CLI_MAJOR=$(aws --version 2>&1 | grep -oE 'aws-cli/[0-9]+' | cut -d/ -f2)
if [[ "${AWS_CLI_MAJOR}" -lt 2 ]]; then
  echo "Error: AWS CLI v2 is required (found v${AWS_CLI_MAJOR})."
  echo "Install it from: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
  exit 1
fi

# ─── Defaults ────────────────────────────────────────────────────────────────

AWS_PROFILE=""
PI_HOST=""
THING_NAME=""
AWS_REGION=""
KVS_INSTALL_DIR="/opt/amazon-kinesis-video-streams-webrtc-sdk-c"

# ─── Parse arguments ─────────────────────────────────────────────────────────

usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --profile PROFILE     AWS CLI profile name (required)
  --pi-host HOST        SSH target for the Pi, e.g. pi@192.168.1.100 (required)
  --thing-name NAME     AWS IoT Thing name for this device (prompted if omitted)
  --region REGION       AWS region (defaults to profile region, then us-east-1)
  -h, --help            Show this help message

Example:
  $0 --profile work --pi-host pi@192.168.1.100 --thing-name MyCamera
EOF
  exit 1
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --profile)    AWS_PROFILE="$2"; shift 2 ;;
    --pi-host)    PI_HOST="$2"; shift 2 ;;
    --thing-name) THING_NAME="$2"; shift 2 ;;
    --region)     AWS_REGION="$2"; shift 2 ;;
    -h|--help)    usage ;;
    *)            echo "Unknown option: $1"; usage ;;
  esac
done

# ─── Validate inputs ─────────────────────────────────────────────────────────

if [[ -z "$AWS_PROFILE" ]]; then
  echo "Error: --profile is required"
  usage
fi

if [[ -z "$PI_HOST" ]]; then
  echo "Error: --pi-host is required"
  usage
fi

if [[ -z "$THING_NAME" ]]; then
  read -p "Enter a name for your IoT Thing: " THING_NAME
  if [[ -z "$THING_NAME" ]]; then
    echo "Error: Thing name cannot be empty"
    exit 1
  fi
fi

# Resolve region: explicit flag > profile config > fallback
if [[ -z "$AWS_REGION" ]]; then
  AWS_REGION=$(aws configure get region --profile "${AWS_PROFILE}" 2>/dev/null || echo "us-east-1")
fi

AWS_CMD="aws --profile ${AWS_PROFILE} --region ${AWS_REGION}"

# Verify AWS session is active
echo "=== Verifying AWS credentials ==="
if ! ${AWS_CMD} sts get-caller-identity &>/dev/null; then
  echo "AWS session is not active. Logging in..."
  aws sso login --profile "${AWS_PROFILE}"
fi
CALLER_IDENTITY=$(${AWS_CMD} sts get-caller-identity)
echo "Authenticated as: $(echo "$CALLER_IDENTITY" | jq -r '.Arn')"
echo ""

# Verify SSH connectivity to Pi and resolve remote home directory
echo "=== Verifying SSH connectivity to ${PI_HOST} ==="
PI_HOME=$(ssh -o ConnectTimeout=5 -o BatchMode=yes "${PI_HOST}" 'echo $HOME' 2>/dev/null) || {
  echo "Error: Cannot SSH to ${PI_HOST}. Check your SSH keys and network."
  exit 1
}
PI_WORK_DIR="${PI_HOME}/kvs-webrtc-setup"
echo "SSH connection verified. Remote home: ${PI_HOME}"
echo ""

# ─── Local staging directory ─────────────────────────────────────────────────

STAGING_DIR=$(mktemp -d)
IOT_DIR="${STAGING_DIR}/iot"
CERTS_DIR="${IOT_DIR}/certs"
CMD_RESULTS_DIR="${IOT_DIR}/cmd-responses"

mkdir -p "${CERTS_DIR}" "${CMD_RESULTS_DIR}"

cleanup() {
  echo "Cleaning up staging directory..."
  rm -rf "${STAGING_DIR}"
}
trap cleanup EXIT

# ─── IoT Provisioning (runs locally with AWS credentials) ────────────────────

THING_TYPE=kvs_example_camera
IAM_ROLE=KVSCameraCertificateBasedIAMRole
IAM_POLICY=KVSCameraIAMPolicy
IOT_ROLE_ALIAS=KvsCameraIoTRoleAlias
IOT_POLICY=KvsCameraIoTPolicy

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Provisioning AWS IoT resources ==="
echo "  Thing Name : ${THING_NAME}"
echo "  Thing Type : ${THING_TYPE}"
echo "  Region     : ${AWS_REGION}"
echo ""

# Save thing metadata
echo "${THING_NAME}" > "${IOT_DIR}/thing-name"
echo "${IOT_ROLE_ALIAS}" > "${IOT_DIR}/role-alias"

# Create Thing Type
if ${AWS_CMD} iot describe-thing-type --thing-type-name "${THING_TYPE}" &>/dev/null; then
  echo "Thing type '${THING_TYPE}' already exists."
else
  echo "Creating thing type '${THING_TYPE}'..."
  ${AWS_CMD} iot create-thing-type --thing-type-name "${THING_TYPE}"
fi

# Create Thing
if ${AWS_CMD} iot describe-thing --thing-name "${THING_NAME}" &>/dev/null; then
  echo "Thing '${THING_NAME}' already exists."
else
  echo "Creating thing '${THING_NAME}'..."
  ${AWS_CMD} iot create-thing --thing-name "${THING_NAME}" --thing-type-name "${THING_TYPE}"
fi

# Create IAM Role
if ${AWS_CMD} iam get-role --role-name "${IAM_ROLE}" &>/dev/null; then
  echo "IAM role '${IAM_ROLE}' already exists."
  ${AWS_CMD} iam get-role --role-name "${IAM_ROLE}" > "${CMD_RESULTS_DIR}/iam-role.json"
else
  echo "Creating IAM role '${IAM_ROLE}'..."
  ${AWS_CMD} iam create-role --role-name "${IAM_ROLE}" \
    --assume-role-policy-document "file://${SCRIPT_DIR}/iot/iam-policy-document.json" \
    > "${CMD_RESULTS_DIR}/iam-role.json"
fi

# Attach IAM Role Policy
if ${AWS_CMD} iam get-role-policy --role-name "${IAM_ROLE}" --policy-name "${IAM_POLICY}" &>/dev/null; then
  echo "IAM role policy '${IAM_POLICY}' already exists."
else
  echo "Attaching IAM role policy '${IAM_POLICY}'..."
  ${AWS_CMD} iam put-role-policy --role-name "${IAM_ROLE}" \
    --policy-name "${IAM_POLICY}" \
    --policy-document "file://${SCRIPT_DIR}/iot/iam-permission-document.json"
fi

# Create IoT Role Alias
if ${AWS_CMD} iot describe-role-alias --role-alias "${IOT_ROLE_ALIAS}" &>/dev/null; then
  echo "IoT role alias '${IOT_ROLE_ALIAS}' already exists."
  ${AWS_CMD} iot describe-role-alias --role-alias "${IOT_ROLE_ALIAS}" \
    > "${CMD_RESULTS_DIR}/iot-role-alias.json"
else
  echo "Creating IoT role alias '${IOT_ROLE_ALIAS}'..."
  ROLE_ARN=$(jq -r '.Role.Arn' "${CMD_RESULTS_DIR}/iam-role.json")
  ${AWS_CMD} iot create-role-alias --role-alias "${IOT_ROLE_ALIAS}" \
    --role-arn "${ROLE_ARN}" \
    --credential-duration-seconds 3600 \
    > "${CMD_RESULTS_DIR}/iot-role-alias.json"
fi

# Create IoT Policy
if ${AWS_CMD} iot get-policy --policy-name "${IOT_POLICY}" &>/dev/null; then
  echo "IoT policy '${IOT_POLICY}' already exists."
else
  echo "Creating IoT policy '${IOT_POLICY}'..."
  ROLE_ALIAS_ARN=$(jq -r '.roleAliasDescription.roleAliasArn' "${CMD_RESULTS_DIR}/iot-role-alias.json")

  cat > "${STAGING_DIR}/iot-policy-document.json" <<POLICYEOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["iot:Connect"],
      "Resource": "${ROLE_ALIAS_ARN}"
    },
    {
      "Effect": "Allow",
      "Action": ["iot:AssumeRoleWithCertificate"],
      "Resource": "${ROLE_ALIAS_ARN}"
    }
  ]
}
POLICYEOF

  ${AWS_CMD} iot create-policy --policy-name "${IOT_POLICY}" \
    --policy-document "file://${STAGING_DIR}/iot-policy-document.json"
fi

# Create device certificate and keys
if [[ ! -f "${CERTS_DIR}/device.cert.pem" ]]; then
  echo "Creating device certificate and keys..."
  ${AWS_CMD} iot create-keys-and-certificate --set-as-active \
    --certificate-pem-outfile "${CERTS_DIR}/device.cert.pem" \
    --public-key-outfile "${CERTS_DIR}/device.public.key" \
    --private-key-outfile "${CERTS_DIR}/device.private.key" \
    > "${CMD_RESULTS_DIR}/keys-and-certificate.json"

  CERT_ARN=$(jq -r '.certificateArn' "${CMD_RESULTS_DIR}/keys-and-certificate.json")

  echo "Attaching IoT policy to certificate..."
  ${AWS_CMD} iot attach-policy --policy-name "${IOT_POLICY}" --target "${CERT_ARN}"

  echo "Attaching thing principal..."
  ${AWS_CMD} iot attach-thing-principal --thing-name "${THING_NAME}" --principal "${CERT_ARN}"
else
  echo "Device certificate already exists in staging directory."
fi

# Download root CA
if [[ ! -f "${CERTS_DIR}/root-CA.crt" ]]; then
  echo "Downloading Amazon root CA certificate..."
  curl --silent 'https://www.amazontrust.com/repository/SFSRootCAG2.pem' \
    --output "${CERTS_DIR}/root-CA.crt"
fi

# Get credential provider endpoint
echo "Fetching IoT credential provider endpoint..."
CREDENTIAL_ENDPOINT=$(${AWS_CMD} iot describe-endpoint --endpoint-type iot:CredentialProvider --output text)
echo "${CREDENTIAL_ENDPOINT}" > "${IOT_DIR}/credential-provider-endpoint"

echo ""
echo "=== AWS IoT provisioning complete ==="
echo "  Thing Name              : ${THING_NAME}"
echo "  Credential Endpoint     : ${CREDENTIAL_ENDPOINT}"
echo "  Certificates staged in  : ${CERTS_DIR}"
echo ""

# ─── Generate the run script ─────────────────────────────────────────────────

echo "=== Generating run script ==="

cat > "${STAGING_DIR}/run-kvs-webrtc-client-master-sample.sh" <<RUNEOF
#!/bin/bash
KVS_SDK_HOME=${KVS_INSTALL_DIR}

export AWS_DEFAULT_REGION=${AWS_REGION}
export AWS_IOT_CORE_CREDENTIAL_ENDPOINT=${CREDENTIAL_ENDPOINT}
export AWS_IOT_CORE_ROLE_ALIAS=${IOT_ROLE_ALIAS}
export AWS_IOT_CORE_THING_NAME=${THING_NAME}

export AWS_IOT_CORE_CERT=\${KVS_SDK_HOME}/iot/certs/device.cert.pem
export AWS_IOT_CORE_PRIVATE_KEY=\${KVS_SDK_HOME}/iot/certs/device.private.key
export IOT_CA_CERT_PATH=\${KVS_SDK_HOME}/iot/certs/root-CA.crt
export AWS_KVS_CACERT_PATH=\${KVS_SDK_HOME}/certs/cert.pem

export DEBUG_LOG_SDP=TRUE
export AWS_KVS_LOG_LEVEL=1
export AWS_ENABLE_FILE_LOGGING=TRUE

# GStreamer pipeline for video-only streaming (libcamerasrc for Raspberry Pi cameras).
# Edit this to change resolution, framerate, encoder settings, etc. without recompiling.
# The pipeline MUST end with: appsink sync=TRUE emit-signals=TRUE name=appsink-video
export KVS_GST_VIDEO_PIPELINE="libcamerasrc ! video/x-raw,width=1280,height=720,framerate=30/1 ! queue ! videoconvert ! video/x-raw,format=I420 ! x264enc bframes=0 speed-preset=veryfast bitrate=512 byte-stream=TRUE tune=zerolatency key-int-max=30 ! video/x-h264,stream-format=byte-stream,alignment=au ! appsink sync=TRUE emit-signals=TRUE name=appsink-video"

\${KVS_SDK_HOME}/build/samples/kvsWebrtcClientMasterGstSample ${THING_NAME}
RUNEOF

chmod 755 "${STAGING_DIR}/run-kvs-webrtc-client-master-sample.sh"

# ─── Deploy to Raspberry Pi ──────────────────────────────────────────────────

echo "=== Deploying to Raspberry Pi (${PI_HOST}) ==="

# Create working directory on Pi
ssh "${PI_HOST}" "mkdir -p ${PI_WORK_DIR}"

# Copy IoT certs and config to Pi
echo "Copying IoT certificates and config..."
scp -r "${IOT_DIR}" "${PI_HOST}:${PI_WORK_DIR}/iot"

# Copy the run script
echo "Copying run script..."
scp "${STAGING_DIR}/run-kvs-webrtc-client-master-sample.sh" "${PI_HOST}:${PI_WORK_DIR}/"

# Copy the setup script, patch script, and service file to Pi
echo "Copying setup script and service file..."
scp "${SCRIPT_DIR}/setup-pi.sh" "${PI_HOST}:${PI_WORK_DIR}/"
scp "${SCRIPT_DIR}/patch-gst-pipeline.sh" "${PI_HOST}:${PI_WORK_DIR}/"
scp "${SCRIPT_DIR}/kvs-webrtc.service" "${PI_HOST}:${PI_WORK_DIR}/"

echo ""
echo "=== Running remote setup on Raspberry Pi ==="
echo "This will install dependencies and build the SDK. This may take a while..."
echo ""

# Run the setup script on the Pi
ssh -t "${PI_HOST}" "chmod +x ${PI_WORK_DIR}/setup-pi.sh && ${PI_WORK_DIR}/setup-pi.sh"

echo ""
echo "=========================================="
echo "  Setup complete!"
echo "=========================================="
echo ""
echo "Your Raspberry Pi is now configured as IoT Thing '${THING_NAME}'."
echo ""
echo "Check the service status:"
echo "  ssh ${PI_HOST} 'sudo systemctl status kvs-webrtc.service'"
echo ""
echo "View logs:"
echo "  ssh ${PI_HOST} 'tail -f /var/log/kvs-webrtc.log'"
echo ""
echo "Test your camera at:"
echo "  https://awslabs.github.io/amazon-kinesis-video-streams-webrtc-sdk-js/examples/index.html"
echo ""

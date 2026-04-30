#!/bin/bash
#
# setup-pi.sh
#
# Runs ON the Raspberry Pi (invoked via SSH from provision-local.sh).
# Installs system dependencies, clones and builds the KVS WebRTC SDK,
# and installs the systemd service.
#
# Uses BUILD_DEPENDENCIES=OFF to speed up compilation by relying on
# system packages for libsrtp and libusrsctp. libwebsockets is built
# from source because the SDK requires v4.3.5 and Bookworm ships 4.1.6.
#

set -euo pipefail

WORK_DIR="${HOME}/kvs-webrtc-setup"
KVS_INSTALL_DIR="/opt/amazon-kinesis-video-streams-webrtc-sdk-c"
SDK_REPO="https://github.com/awslabs/amazon-kinesis-video-streams-webrtc-sdk-c"
LWS_VERSION="v4.3.5"

echo "=== Raspberry Pi Setup ==="
echo ""

# ─── Install system dependencies ─────────────────────────────────────────────

echo "=== Installing system packages ==="
sudo apt-get update -qq
sudo apt-get install -y \
  git \
  cmake \
  pkg-config \
  libssl-dev \
  libmbedtls-dev \
  libcurl4-openssl-dev \
  liblog4cplus-dev \
  libsrtp2-dev \
  libusrsctp-dev \
  libgstreamer1.0-dev \
  libgstreamer-plugins-base1.0-dev \
  gstreamer1.0-plugins-base-apps \
  gstreamer1.0-plugins-bad \
  gstreamer1.0-plugins-good \
  gstreamer1.0-plugins-ugly \
  gstreamer1.0-tools \
  gstreamer1.0-libcamera

echo ""

# ─── Validate camera hardware ────────────────────────────────────────────────
# Catch common configuration issues before spending time on the build.

echo "=== Checking camera configuration ==="

# Check that camera_auto_detect or a camera dtoverlay is enabled in boot config
BOOT_CONFIG=""
for f in /boot/firmware/config.txt /boot/config.txt; do
  if [[ -f "$f" ]]; then
    BOOT_CONFIG="$f"
    break
  fi
done

if [[ -n "${BOOT_CONFIG}" ]]; then
  if ! grep -qE '^camera_auto_detect=1|^dtoverlay=imx|^dtoverlay=ov' "${BOOT_CONFIG}" 2>/dev/null; then
    echo "WARNING: No camera configuration found in ${BOOT_CONFIG}."
    echo "  Ensure 'camera_auto_detect=1' is set, or add the appropriate"
    echo "  dtoverlay for your camera module (e.g. dtoverlay=imx219)."
    echo "  Then reboot before running this script again."
    echo ""
    read -p "Continue anyway? [y/N] " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      exit 1
    fi
  fi
else
  echo "WARNING: Could not find boot config file. Skipping camera config check."
fi

# Check that a camera is actually detected by libcamera
CAMERA_COUNT=0
if command -v rpicam-hello &>/dev/null; then
  CAMERA_COUNT=$(rpicam-hello --list-cameras 2>&1 | grep -cE '^[0-9]+ :' || true)
elif command -v libcamera-hello &>/dev/null; then
  CAMERA_COUNT=$(libcamera-hello --list-cameras 2>&1 | grep -cE '^[0-9]+ :' || true)
fi

if [[ "${CAMERA_COUNT}" -eq 0 ]]; then
  echo ""
  echo "ERROR: No camera detected by libcamera."
  echo ""
  echo "Troubleshooting steps:"
  echo "  1. Verify the camera ribbon cable is firmly seated at both ends"
  echo "  2. Ensure the cable is oriented correctly (contacts facing the board)"
  echo "  3. Check that your boot config (${BOOT_CONFIG:-/boot/firmware/config.txt})"
  echo "     contains 'camera_auto_detect=1'"
  echo "  4. Reboot after making any changes: sudo reboot"
  echo "  5. Test with: rpicam-hello --list-cameras"
  echo ""
  read -p "Continue without a detected camera? [y/N] " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
else
  echo "Camera detected (${CAMERA_COUNT} camera(s) found)."
fi

# Check that the libcamera GStreamer plugin is functional
if ! gst-inspect-1.0 libcamerasrc &>/dev/null; then
  echo "WARNING: GStreamer libcamerasrc plugin not found."
  echo "  The gstreamer1.0-libcamera package may not have installed correctly."
  echo "  The SDK will not be able to capture video from the camera."
fi

echo ""

# ─── Build libwebsockets from source ─────────────────────────────────────────
# The SDK requires libwebsockets v4.3.5 but Bookworm only ships 4.1.6.
# Build it once and install to /usr/local so the SDK can find it.

LWS_MARKER="/usr/local/lib/pkgconfig/libwebsockets.pc"
if [[ -f "${LWS_MARKER}" ]] && pkg-config --atleast-version=4.3.5 libwebsockets 2>/dev/null; then
  echo "=== libwebsockets >= 4.3.5 already installed, skipping ==="
else
  echo "=== Building libwebsockets ${LWS_VERSION} from source ==="
  LWS_SRC_DIR="${WORK_DIR}/libwebsockets"

  if [[ ! -d "${LWS_SRC_DIR}" ]]; then
    git clone --branch "${LWS_VERSION}" --depth 1 \
      https://github.com/warmcat/libwebsockets.git "${LWS_SRC_DIR}"
  fi

  mkdir -p "${LWS_SRC_DIR}/build"
  cd "${LWS_SRC_DIR}/build"
  cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DLWS_WITH_STATIC=ON \
    -DLWS_WITH_SHARED=ON \
    -DLWS_WITHOUT_TESTAPPS=ON \
    -DLWS_WITHOUT_TEST_SERVER=ON \
    -DLWS_WITHOUT_TEST_PING=ON \
    -DLWS_WITHOUT_TEST_CLIENT=ON
  make -j$(nproc)
  sudo make install
  sudo ldconfig
  cd "${WORK_DIR}"

  echo "libwebsockets ${LWS_VERSION} installed to /usr/local"
fi

echo ""

# ─── Clone and build the SDK ─────────────────────────────────────────────────

SDK_SRC_DIR="${WORK_DIR}/amazon-kinesis-video-streams-webrtc-sdk-c"

if [[ ! -d "${SDK_SRC_DIR}" ]]; then
  echo "=== Cloning KVS WebRTC SDK ==="
  git clone "${SDK_REPO}" "${SDK_SRC_DIR}"
else
  echo "=== SDK source already present, pulling latest ==="
  cd "${SDK_SRC_DIR}"
  git pull
  cd "${WORK_DIR}"
fi

echo "=== Patching SDK for configurable GStreamer pipeline ==="
# Raspberry Pi OS Bookworm uses libcamera instead of the legacy camera stack.
# Instead of hardcoding a pipeline, patch the SDK to read from environment
# variables (KVS_GST_VIDEO_PIPELINE / KVS_GST_AUDIO_VIDEO_PIPELINE) so the
# pipeline can be tuned without recompiling.
GSTMEDIA="${SDK_SRC_DIR}/samples/common/GstMedia.c"
if [[ -f "${GSTMEDIA}" ]]; then
  bash "${WORK_DIR}/patch-gst-pipeline.sh" "${GSTMEDIA}"
else
  echo "WARNING: GstMedia.c not found at expected path, skipping pipeline patch"
fi

echo "=== Building SDK with BUILD_DEPENDENCIES=OFF ==="
mkdir -p "${SDK_SRC_DIR}/build"
cd "${SDK_SRC_DIR}/build"
cmake .. \
  -DBUILD_DEPENDENCIES=OFF \
  -DIOT_CORE_ENABLE_CREDENTIALS=ON \
  -DCMAKE_PREFIX_PATH=/usr/local
make -j$(nproc)
cd "${WORK_DIR}"

echo ""

# ─── Install to /opt/ ────────────────────────────────────────────────────────

echo "=== Installing to ${KVS_INSTALL_DIR} ==="
sudo mkdir -p "${KVS_INSTALL_DIR}"

# Copy the built SDK
sudo cp -r "${SDK_SRC_DIR}/build" "${KVS_INSTALL_DIR}/"
sudo cp -r "${SDK_SRC_DIR}/certs" "${KVS_INSTALL_DIR}/" 2>/dev/null || true

# Copy IoT certs and config (placed here by provision-local.sh via SCP)
sudo cp -r "${WORK_DIR}/iot" "${KVS_INSTALL_DIR}/"
sudo chmod -R +r "${KVS_INSTALL_DIR}/iot/"

# Copy the run script
sudo cp "${WORK_DIR}/run-kvs-webrtc-client-master-sample.sh" "${KVS_INSTALL_DIR}/"
sudo chmod 755 "${KVS_INSTALL_DIR}/run-kvs-webrtc-client-master-sample.sh"

echo ""

# ─── Install systemd service ─────────────────────────────────────────────────

echo "=== Installing systemd service ==="
sudo cp "${WORK_DIR}/kvs-webrtc.service" /etc/systemd/system/kvs-webrtc.service
sudo systemctl daemon-reload
sudo systemctl enable kvs-webrtc.service
sudo systemctl start kvs-webrtc.service

echo ""
echo "=== Raspberry Pi setup complete ==="
echo ""
echo "Service status:"
sudo systemctl status kvs-webrtc.service --no-pager || true

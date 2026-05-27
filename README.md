# Amazon Kinesis Video Streams for WebRTC Demo for Raspberry Pi Devices

Demo assets and instructions to quickly get started with WebRTC using Amazon Kinesis Video Streams on Raspberry Pi devices.

## What does this repo do?

This repository contains bash scripts that build the [Amazon Kinesis Video Streams for WebRTC SDK for C](https://github.com/awslabs/amazon-kinesis-video-streams-webrtc-sdk-c) and provision the necessary AWS resources. The scripts will:

* Provision your device as an AWS IoT Core Thing (with certificates, policies, and role aliases)
* Install development and runtime dependencies for the SDK on the Pi
* Build libwebsockets from source (the SDK requires v4.3.5; Raspberry Pi OS Bookworm ships 4.1.6)
* Compile the SDK with `BUILD_DEPENDENCIES=OFF` using system packages where possible
* Generate a "run" script for the SDK sample applications
* Configure a systemd service so the application runs automatically

There are two ways to use this repo:

1. **Local-to-Remote (recommended)** — Run provisioning from your laptop/desktop, deploy to the Pi over SSH
2. **All-on-Pi (legacy)** — Run everything directly on the Raspberry Pi

## Prerequisites

Before using this repo, you need:

1. **An AWS account** with permissions to create IoT and IAM resources (see [Minimum IAM permissions](#minimum-iam-permissions) below)
2. **A Raspberry Pi** with:
   - Raspberry Pi OS installed ([setup guide](https://projects.raspberrypi.org/en/projects/raspberry-pi-setting-up), [Raspberry Pi Imager](https://www.raspberrypi.com/software/))
   - A camera module attached and enabled ([camera setup](https://picamera.readthedocs.io/en/latest/quickstart.html))
   - Connected to a network reachable from your local machine
   - SSH enabled with key-based authentication (e.g. `ssh pi@192.168.1.100`)
   - Updated packages and git installed:
     ```bash
     sudo apt update && sudo apt install git -y
     ```
3. **On your local machine** (laptop/desktop):
   - [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
   - `jq` (`brew install jq` on macOS, `apt install jq` on Linux)
   - SSH key-based access to the Pi

## Minimum IAM permissions

The provisioning scripts do not require administrator access. A minimal IAM policy is provided in [`iot/provisioning-iam-policy.json`](iot/provisioning-iam-policy.json). Before using it, replace `<ACCOUNT_ID>` with your AWS account ID.

The policy grants permissions for:

| Service | Actions | Purpose |
|---|---|---|
| IoT | CreateThing, CreateThingType, DescribeThing, DescribeThingType | Register the Pi as an IoT Thing |
| IoT | CreateKeysAndCertificate, AttachPolicy, AttachThingPrincipal | Create and attach device certificates |
| IoT | CreatePolicy, GetPolicy, CreateRoleAlias, DescribeRoleAlias, DescribeEndpoint | Set up IoT credential provider |
| IAM | CreateRole, GetRole, PutRolePolicy, GetRolePolicy, PassRole | Create the role that IoT assumes for KVS access |
| STS | GetCallerIdentity | Verify the active AWS session |

You can create this policy in the AWS Console under IAM > Policies > Create Policy (JSON tab), or via the CLI:

```bash
aws iam create-policy \
  --policy-name KVSWebRTCProvisioningPolicy \
  --policy-document file://iot/provisioning-iam-policy.json
```

Then attach it to your IAM user, group, or SSO permission set.

**Note:** KVS signaling channel permissions (`CreateSignalingChannel`, `ConnectAsMaster`, etc.) are not needed by the provisioning user. Those permissions are granted to the IoT role (`KVSCameraCertificateBasedIAMRole`) which the Pi assumes at runtime via the IoT credential provider. See [`iot/iam-permission-document.json`](iot/iam-permission-document.json) for the runtime permissions.

---

## Option 1: Local-to-Remote Setup (Recommended)

This approach runs AWS provisioning from your local machine using AWS SSO (or any configured credentials), then deploys everything to the Pi over SSH. No AWS credentials are ever stored on the Pi.

### Step 1: Clone this repo (on your local machine)

```bash
git clone https://github.com/dave-malone/aws-kvs-webrtc-demo-for-raspberry-pi
cd aws-kvs-webrtc-demo-for-raspberry-pi
```

### Step 2: Configure AWS credentials

If you use AWS IAM Identity Center (SSO), run the setup helper:

```bash
./setup-aws-sso.sh myprofile
```

This walks you through `aws configure sso` interactively. You'll need your Identity Center start URL, account ID, and role name.

If you already have a working AWS CLI profile (SSO, IAM user, or otherwise), skip this step.

### Step 3: Log in

```bash
aws sso login --profile myprofile
```

### Step 4: Provision and deploy

```bash
./provision-local.sh \
  --profile myprofile \
  --pi-host pi@192.168.1.100 \
  --thing-name MyCameraDevice
```

This single command will:
1. Verify prerequisites (AWS CLI v2, jq, ssh, scp, curl) and AWS session
2. Create the IoT Thing, IAM role, IoT policies, and device certificates locally
3. SCP the certificates and configuration to the Pi
4. SSH into the Pi to install dependencies, build libwebsockets and the SDK, and start the systemd service

### Step 5: Verify

```bash
ssh pi@192.168.1.100 'sudo systemctl status kvs-webrtc.service'
```

---

## Option 2: All-on-Pi Setup (Legacy)

This approach runs everything directly on the Raspberry Pi. It requires temporary AWS access keys on the device.

### Obtain AWS credentials

Create a temporary AWS access key pair ([instructions](https://repost.aws/knowledge-center/create-access-key)) and set them on your Pi:

```bash
export AWS_ACCESS_KEY_ID=<your-access-key>
export AWS_SECRET_ACCESS_KEY=<your-secret-key>
export AWS_DEFAULT_REGION=us-east-1
```

### Clone and run

```bash
git clone --recurse-submodules https://github.com/dave-malone/aws-kvs-webrtc-demo-for-raspberry-pi
cd aws-kvs-webrtc-demo-for-raspberry-pi
./easy_install.sh YOUR_THING_NAME
```

**Important:** Delete the temporary AWS access key pair after setup completes.

---

## Test your camera

Once the service is running, navigate to the [KVS WebRTC Test Page](https://awslabs.github.io/amazon-kinesis-video-streams-webrtc-sdk-js/examples/index.html), enter your AWS region, credentials, and device name, then click "Start Viewer" to see a live feed.

## Service management

```bash
# Check status
sudo systemctl status kvs-webrtc.service

# View logs
tail -f /var/log/kvs-webrtc.log

# Restart
sudo systemctl restart kvs-webrtc.service
```

## Clean up

To remove the KVS WebRTC installation from the Pi:

```bash
# Run on the Pi (or via SSH)
sudo systemctl stop kvs-webrtc.service
sudo systemctl disable kvs-webrtc.service
sudo rm /etc/systemd/system/kvs-webrtc.service
sudo systemctl daemon-reload
sudo rm -rf /opt/amazon-kinesis-video-streams-webrtc-sdk-c
```

If using the legacy approach, ensure you have deleted the temporary AWS access key pair.

---

## Customizing the GStreamer pipeline

The SDK samples use a GStreamer pipeline to capture video from the camera and encode it for WebRTC streaming. By default, the setup scripts patch the SDK to read the pipeline from environment variables, so you can change resolution, framerate, encoder settings, or even the camera source without recompiling.

Two environment variables are supported:

| Variable | Used when | Required appsink names |
|---|---|---|
| `KVS_GST_VIDEO_PIPELINE` | Video-only streaming | `appsink-video` |
| `KVS_GST_AUDIO_VIDEO_PIPELINE` | Audio+video streaming | `appsink-video` and `appsink-audio` |

If the variable is not set or empty, the SDK falls back to its built-in default pipeline.

The pipeline is configured in the run script at `/opt/amazon-kinesis-video-streams-webrtc-sdk-c/run-kvs-webrtc-client-master-sample.sh`. Edit the `KVS_GST_VIDEO_PIPELINE` line and restart the service:

```bash
sudo nano /opt/amazon-kinesis-video-streams-webrtc-sdk-c/run-kvs-webrtc-client-master-sample.sh
sudo systemctl restart kvs-webrtc.service
```

### Default pipeline (Raspberry Pi with libcamera)

```
libcamerasrc ! video/x-raw,width=1280,height=720,framerate=30/1 !
  queue ! videoconvert ! video/x-raw,format=I420 !
  x264enc bframes=0 speed-preset=veryfast bitrate=512 byte-stream=TRUE
    tune=zerolatency key-int-max=30 !
  video/x-h264,stream-format=byte-stream,alignment=au !
  appsink sync=TRUE emit-signals=TRUE name=appsink-video
```

### Example: lower resolution for reduced CPU usage

```
libcamerasrc ! video/x-raw,width=640,height=480,framerate=15/1 !
  queue ! videoconvert ! video/x-raw,format=I420 !
  x264enc bframes=0 speed-preset=ultrafast bitrate=256 byte-stream=TRUE
    tune=zerolatency key-int-max=15 !
  video/x-h264,stream-format=byte-stream,alignment=au !
  appsink sync=TRUE emit-signals=TRUE name=appsink-video
```

### Example: test pattern (no camera needed)

```
videotestsrc is-live=TRUE pattern=ball !
  video/x-raw,width=1280,height=720,framerate=30/1 !
  queue ! videoconvert ! video/x-raw,format=I420 !
  x264enc bframes=0 speed-preset=veryfast bitrate=512 byte-stream=TRUE
    tune=zerolatency key-int-max=30 !
  video/x-h264,stream-format=byte-stream,alignment=au !
  appsink sync=TRUE emit-signals=TRUE name=appsink-video
```

### Tips

- Use `gst-launch-1.0 <your pipeline elements> ! fakesink` to test a pipeline before putting it in the run script
- The pipeline must be a single string on one line in the run script (no line breaks)
- The `appsink` element names (`appsink-video`, `appsink-audio`) must match exactly — the SDK uses these names to pull frames

---

## What's tested (and what's not)

This repo is tested with **one-way video streaming from the Pi to a browser viewer**. Specifically:

- Video-only, Pi → cloud → browser viewer (using the KVS WebRTC test page)
- Camera auto-detection with fallback to test pattern
- IoT Core credential provider for authentication

### Not tested but possible: audio + video streaming

To stream audio alongside video from the Pi, you would need:

1. A USB microphone or audio input device connected to the Pi
2. Set `KVS_GST_AUDIO_VIDEO_PIPELINE` instead of `KVS_GST_VIDEO_PIPELINE`

Example pipeline (untested):

```
libcamerasrc ! video/x-raw,width=1280,height=720,framerate=30/1 !
  queue ! videoconvert ! video/x-raw,format=I420 !
  x264enc bframes=0 speed-preset=veryfast bitrate=512 byte-stream=TRUE
    tune=zerolatency key-int-max=30 !
  video/x-h264,stream-format=byte-stream,alignment=au !
  appsink sync=TRUE emit-signals=TRUE name=appsink-video
alsasrc device=hw:0 !
  queue leaky=2 max-size-buffers=400 !
  audioconvert ! audioresample !
  opusenc !
  audio/x-opus,rate=48000,channels=2 !
  appsink sync=TRUE emit-signals=TRUE name=appsink-audio
```

Note: this is a single pipeline string with both video and audio branches. The `alsasrc device=hw:0` would need to match your actual audio device (check with `arecord -l`).

### Not tested: bidirectional audio/video

WebRTC supports bidirectional media, and the SDK sample application includes a `receiveGstreamerAudioVideo` function for handling incoming media. To use bidirectional streaming, you would need:

1. A speaker connected to the Pi (for receiving audio)
2. A display connected to the Pi (for receiving video) — the Pi cannot be headless
3. Modifications to the SDK sample application to route received media to appropriate GStreamer sinks (e.g. `alsasink` for audio, `autovideosink` for video)

This is significantly more complex than one-way streaming and is not configured or tested by the scripts in this repo.

---

## Tested configurations

| Raspberry Pi Model | OS | Architecture | Kernel | Status |
|---|---|---|---|---|
| Raspberry Pi 4 Model B | Raspbian Bookworm (12) | armhf (32-bit userspace) | 6.12 aarch64 | Tested, working |
| Raspberry Pi Zero 2 W | Raspbian Trixie (13) | armhf (32-bit userspace) | 6.12 armv7l | Tested, working |
| Raspberry Pi 4 Model B | Raspberry Pi OS Bookworm (12) | arm64 (64-bit) | — | Untested, may have issues |
| Raspberry Pi 5 | — | — | — | Untested |
| Raspberry Pi 3 | — | — | — | Untested |

**Notes:**
- The 32-bit (armhf) Raspbian image is the tested configuration. The 64-bit (arm64) Raspberry Pi OS image may have different package names or library paths — if you test it, please report your results.
- Trixie (Debian 13) on armhf requires building `usrsctp` from source due to type signature mismatches with the system package. The `setup-pi.sh` script detects this automatically.
- Older OS versions (Bullseye and earlier) use the legacy camera stack (`raspistill`, `v4l2`) instead of `libcamera`. The GStreamer pipeline patch in `setup-pi.sh` targets Bookworm/Trixie's `libcamerasrc` and will not work on Bullseye without modification.

---

## Troubleshooting

### Wi-Fi not connecting after flashing with Raspberry Pi Imager

On recent Bookworm images, the Wi-Fi configuration set through Raspberry Pi Imager (or `raspi-config`) may not apply correctly. NetworkManager has replaced `wpa_supplicant` as the default network manager, and the old configuration methods don't always work.

**Workaround:** Connect a monitor, keyboard, and mouse to the Pi, then use `nmtui` to configure Wi-Fi:

```bash
sudo nmtui
```

Select "Activate a connection", choose your Wi-Fi network, and enter the password. Once connected, you can find the Pi's IP address with `hostname -I` and switch to SSH for the remaining setup.

### No camera detected

If `setup-pi.sh` reports "No camera detected by libcamera":

1. **Check the ribbon cable** — ensure it's firmly seated at both the camera module and the Pi's CSI port, with the contacts facing the correct direction
2. **Verify boot config** — check that `camera_auto_detect=1` is present in `/boot/firmware/config.txt` (or `/boot/config.txt` on older images)
3. **Reboot** after any config changes: `sudo reboot`
4. **Test manually:**
   ```bash
   rpicam-hello --list-cameras
   ```
   You should see at least one camera listed with its supported modes.

### Peer connection established but no video

If the KVS WebRTC test page shows a peer connection but no video feed:

- Check the application logs for GStreamer errors:
  ```bash
  grep -i 'error\|pipeline\|gstreamer' /var/log/kvs-webrtc.log | tail -20
  ```
- Look for kernel errors related to the camera:
  ```bash
  dmesg | grep -i 'unicam\|camera\|csi' | tail -10
  ```
- A common cause is the `Wrong width or height` error in `dmesg`, which means the GStreamer pipeline is trying to open the camera at a resolution the sensor doesn't natively support. This is fixed by the `libcamerasrc` patch in `setup-pi.sh`. If you see this error, rebuild the SDK:
  ```bash
  rm -rf ~/kvs-webrtc-setup/amazon-kinesis-video-streams-webrtc-sdk-c/build
  ~/kvs-webrtc-setup/setup-pi.sh
  ```

### Service fails to start

```bash
sudo systemctl status kvs-webrtc.service
journalctl -u kvs-webrtc.service --no-pager -n 50
```

Common causes:
- **Missing IoT certificates** — verify files exist under `/opt/amazon-kinesis-video-streams-webrtc-sdk-c/iot/certs/`
- **Wrong region** — check that `AWS_DEFAULT_REGION` in the run script matches where your IoT resources were provisioned
- **Clock skew** — TLS connections will fail if the Pi's clock is significantly off. Install and enable NTP: `sudo apt install ntp`

#!/bin/bash
KVS_SDK_HOME=__KVS_INSTALL_DIR__

export AWS_DEFAULT_REGION=__AWS_REGION__
export AWS_IOT_CORE_CREDENTIAL_ENDPOINT=__CREDENTIAL_ENDPOINT__
export AWS_IOT_CORE_ROLE_ALIAS=__IOT_ROLE_ALIAS__
export AWS_IOT_CORE_THING_NAME=__THING_NAME__

export AWS_IOT_CORE_CERT=${KVS_SDK_HOME}/iot/certs/device.cert.pem
export AWS_IOT_CORE_PRIVATE_KEY=${KVS_SDK_HOME}/iot/certs/device.private.key
export IOT_CA_CERT_PATH=${KVS_SDK_HOME}/iot/certs/root-CA.crt
export AWS_KVS_CACERT_PATH=${KVS_SDK_HOME}/certs/cert.pem

export DEBUG_LOG_SDP=TRUE
export AWS_KVS_LOG_LEVEL=1
export AWS_ENABLE_FILE_LOGGING=TRUE

# ─── Detect camera and select GStreamer pipeline ─────────────────────────────
# If a camera is attached, use libcamerasrc. Otherwise, fall back to a test
# pattern so the service still runs and can verify connectivity.
#
# Override by setting KVS_GST_VIDEO_PIPELINE before running this script.

if [[ -z "${KVS_GST_VIDEO_PIPELINE:-}" ]]; then
  CAMERA_COUNT=0
  if command -v rpicam-hello &>/dev/null; then
    CAMERA_COUNT=$(rpicam-hello --list-cameras 2>&1 | grep -cE '^[0-9]+ :' || true)
  elif command -v libcamera-hello &>/dev/null; then
    CAMERA_COUNT=$(libcamera-hello --list-cameras 2>&1 | grep -cE '^[0-9]+ :' || true)
  fi

  if [[ "${CAMERA_COUNT}" -gt 0 ]]; then
    echo "Camera detected — using libcamerasrc pipeline"
    export KVS_GST_VIDEO_PIPELINE="libcamerasrc ! video/x-raw,width=1280,height=720,framerate=30/1 ! queue ! videoconvert ! video/x-raw,format=I420 ! x264enc bframes=0 speed-preset=veryfast bitrate=512 byte-stream=TRUE tune=zerolatency key-int-max=30 ! video/x-h264,stream-format=byte-stream,alignment=au ! appsink sync=TRUE emit-signals=TRUE name=appsink-video"
  else
    echo "No camera detected — using test source pipeline"
    export KVS_GST_VIDEO_PIPELINE="videotestsrc is-live=TRUE pattern=ball ! video/x-raw,width=1280,height=720,framerate=30/1 ! queue ! videoconvert ! video/x-raw,format=I420 ! x264enc bframes=0 speed-preset=veryfast bitrate=512 byte-stream=TRUE tune=zerolatency key-int-max=30 ! video/x-h264,stream-format=byte-stream,alignment=au ! appsink sync=TRUE emit-signals=TRUE name=appsink-video"
  fi
fi

${KVS_SDK_HOME}/build/samples/kvsWebrtcClientMasterGstSample __THING_NAME__

#!/bin/bash
#
# build-kvs-webrtc.sh
#
# Installs build/runtime dependencies and compiles the KVS WebRTC SDK.
# Uses BUILD_DEPENDENCIES=OFF with system packages for libsrtp and
# libusrsctp. Builds libwebsockets v4.3.5 from source since the SDK
# requires it and Bookworm only ships 4.1.6.
#

set -euo pipefail

LWS_VERSION="v4.3.5"

echo "installing amazon-kinesis-video-streams-webrtc-sdk-c build dependencies"
sudo apt-get install -y \
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
  gstreamer1.0-tools

# Build libwebsockets from source (SDK requires v4.3.5, Bookworm has 4.1.6)
LWS_MARKER="/usr/local/lib/pkgconfig/libwebsockets.pc"
if [[ -f "${LWS_MARKER}" ]] && pkg-config --atleast-version=4.3.5 libwebsockets 2>/dev/null; then
  echo "libwebsockets >= 4.3.5 already installed, skipping"
else
  echo "building libwebsockets ${LWS_VERSION} from source"
  LWS_SRC_DIR="$(pwd)/libwebsockets"

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
  cd ../..
fi

# Enable IoT Core Credentials Provider in samples.
# Newer SDK versions use a CMake flag; older versions use a #define in Samples.h.
SAMPLES_H=amazon-kinesis-video-streams-webrtc-sdk-c/samples/Samples.h
if [ ! -f "$SAMPLES_H" ]; then
  SAMPLES_H=amazon-kinesis-video-streams-webrtc-sdk-c/samples/common/Samples.h
fi
if [ -f "$SAMPLES_H" ]; then
  sed -i 's+//#define IOT_CORE_ENABLE_CREDENTIALS  1+#define IOT_CORE_ENABLE_CREDENTIALS  1+g' "$SAMPLES_H"
fi

mkdir -p amazon-kinesis-video-streams-webrtc-sdk-c/build
cd amazon-kinesis-video-streams-webrtc-sdk-c/build

cmake .. \
  -DBUILD_DEPENDENCIES=OFF \
  -DIOT_CORE_ENABLE_CREDENTIALS=ON \
  -DCMAKE_PREFIX_PATH=/usr/local
make -j$(nproc)

cd ../..

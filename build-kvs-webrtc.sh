#!/bin/bash

echo "installing amazon-kinesis-video-streams-webrtc-sdk-c build dependencies"
sudo apt-get install -y \
  libssl-dev \
  libmbedtls-dev \
  libcurl4-openssl-dev \
  liblog4cplus-dev \
  libgstreamer1.0-dev \
  libgstreamer-plugins-base1.0-dev \
  gstreamer1.0-plugins-base-apps \
  gstreamer1.0-plugins-bad \
  gstreamer1.0-plugins-good \
  gstreamer1.0-plugins-ugly \
  gstreamer1.0-tools

# patch CMakeLists.txt; don't build openssl or mbedtls since those are installed via package manager
sed -i 's+build_dependency(openssl ${BUILD_ARGS})+#build_dependency(openssl ${BUILD_ARGS})+g' amazon-kinesis-video-streams-webrtc-sdk-c/CMakeLists.txt
sed -i 's+set(OPENSSL_ROOT_DIR ${OPEN_SRC_INSTALL_PREFIX})+#set(OPENSSL_ROOT_DIR ${OPEN_SRC_INSTALL_PREFIX})+g' amazon-kinesis-video-streams-webrtc-sdk-c/CMakeLists.txt
sed -i 's+build_dependency(mbedtls ${BUILD_ARGS})+#build_dependency(mbedtls ${BUILD_ARGS})+g' amazon-kinesis-video-streams-webrtc-sdk-c/CMakeLists.txt

# patch samples/Samples.h to enable IoT Core Credentials Provider
sed -i 's+//#define IOT_CORE_ENABLE_CREDENTIALS  1+#define IOT_CORE_ENABLE_CREDENTIALS  1+g' amazon-kinesis-video-streams-webrtc-sdk-c/samples/Samples.h

mkdir -p amazon-kinesis-video-streams-webrtc-sdk-c/build
cd amazon-kinesis-video-streams-webrtc-sdk-c/build

#cmake .. -DUSE_MBEDTLS=ON -DUSE_OPENSSL=OFF
cmake ..
make

cd ../..
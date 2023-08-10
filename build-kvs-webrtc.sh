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

# TODO find and uncomment this line prior to build: https://github.com/awslabs/amazon-kinesis-video-streams-webrtc-sdk-c/blob/master/samples/Samples.h#L53

sed -i 's+//#define IOT_CORE_ENABLE_CREDENTIALS  1+#define IOT_CORE_ENABLE_CREDENTIALS  1+g' amazon-kinesis-video-streams-webrtc-sdk-c/samples/Samples.h

mkdir -p amazon-kinesis-video-streams-webrtc-sdk-c/build
cd amazon-kinesis-video-streams-webrtc-sdk-c/build

#cmake .. -DUSE_MBEDTLS=ON -DUSE_OPENSSL=OFF
cmake ..
make

cd ../..
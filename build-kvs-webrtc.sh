#!/bin/bash

echo "installing amazon-kinesis-video-streams-webrtc-sdk-c build dependencies"
sudo apt-get install -y \
  pkg-config \
  cmake \
  zip \
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

mkdir -p amazon-kinesis-video-streams-webrtc-sdk-c/build
cd amazon-kinesis-video-streams-webrtc-sdk-c/build

cmake .. -DUSE_MBEDTLS=ON -DUSE_OPENSSL=OFF
make

sudo mkdir -p /opt/amazon-kinesis-video-streams-webrtc-sdk-c
sudo cp -r amazon-kinesis-video-streams-webrtc-sdk-c/* /opt/amazon-kinesis-video-streams-webrtc-sdk-c/

cd ../..
#!/bin/bash

echo "installing amazon-kinesis-video-streams-webrtc-sdk-c build dependencies"
sudo apt-get install -y \
  pkg-config \
  cmake \
  zip \
  libssl-dev \
  libcurl4-openssl-dev \
  liblog4cplus-dev \
  libgstreamer1.0-dev \
  libgstreamer-plugins-base1.0-dev \
  gstreamer1.0-plugins-base-apps \
  gstreamer1.0-plugins-bad \
  gstreamer1.0-plugins-good \
  gstreamer1.0-plugins-ugly \
  gstreamer1.0-tools

# echo "cloning the amazon-kinesis-video-streams-webrtc-sdk-c repository"
# git clone --recursive https://github.com/dave-malone/amazon-kinesis-video-streams-webrtc-sdk-c

mkdir -p amazon-kinesis-video-streams-webrtc-sdk-c/build
cd amazon-kinesis-video-streams-webrtc-sdk-c/build

cmake .. -DBUILD_TEST=TRUE -DBUILD_DEPENDENCIES=FALSE
make

sudo mkdir -p /opt/
sudo cp -r amazon-kinesis-video-streams-webrtc-sdk-c/ /opt/

cd ../..
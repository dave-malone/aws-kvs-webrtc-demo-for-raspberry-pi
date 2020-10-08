#!/bin/bash

echo "installing amazon-kinesis-video-streams-webrtc-sdk-c run time dependencies"
sudo apt-get install -y \
  pkg-config \
  libgstreamer1.0-0 \
  gstreamer1.0-plugins-base \
  gstreamer1.0-libav \
  gstreamer1.0-doc \
  gstreamer1.0-x \
  gstreamer1.0-alsa \
  gstreamer1.0-gl \
  gstreamer1.0-gtk3 \
  gstreamer1.0-pulseaudio

ulimit -c unlimited

# TODO - pull this down from S3
#unzip kvs-webrtc-sdk-c-rpi-zero-build.zip -d kvs-webrtc-sdk-c-rpi-zero-build
#cd kvs-webrtc-sdk-c-rpi-zero-build

echo "Running webrtc client test to confirm device support"
./amazon-kinesis-video-streams-webrtc-sdk-c/build/tst/webrtc_client_test

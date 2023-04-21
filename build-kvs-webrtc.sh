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

echo "cloning the amazon-kinesis-video-streams-webrtc-sdk-c repository"

if [ -z $AWS_KVS_WEBRTC_SDK ]
then
    AWS_KVS_WEBRTC_SDK=https://github.com/dave-malone/amazon-kinesis-video-streams-webrtc-sdk-c
fi

git clone --recursive $AWS_KVS_WEBRTC_SDK
cd amazon-kinesis-video-streams-webrtc-sdk-c

if [ ! -z $AWS_KVS_WEBRTC_SDK_BRANCH ]
then
  echo "switching to branch $AWS_KVS_WEBRTC_SDK_BRANCH"
  git checkout $AWS_KVS_WEBRTC_SDK_BRANCH
fi

mkdir build
cd build

cmake .. -DBUILD_TEST=TRUE
make

cd ../..

# zip -r kvs-webrtc-sdk-c-build ./build/* ./open-source/lib/* ./certs/*

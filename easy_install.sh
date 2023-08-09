#!/bin/bash

if [[ -z $AWS_ACCESS_KEY_ID || -z $AWS_SECRET_ACCESS_KEY || -z $AWS_DEFAULT_REGION ]]; then
  echo 'AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY and AWS_DEFAULT_REGION must be set'
  exit 1
fi

echo "installing build dependencies"
sudo apt-get install -y jq zip pkg-config cmake

echo "making kvs webrtc directories"
export KVS_WEBRTC_HOME=/opt/amazon-kinesis-video-streams-webrtc-sdk-c
sudo mkdir -p $KVS_WEBRTC_HOME

./install-aws-cli.sh
./build-kvs-webrtc.sh

./iot/provision-thing.sh

echo "moving amazon-kinesis-video-streams-webrtc-sdk-c to /opt/"
sudo mv -r ./amazon-kinesis-video-streams-webrtc-sdk-c/* $KVS_WEBRTC_HOME

./install-kvs-webrtc-service.sh

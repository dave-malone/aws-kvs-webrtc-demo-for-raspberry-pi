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
sudo mkdir -p $KVS_WEBRTC_HOME/iot/cmd-responses
sudo mkdir -p $KVS_WEBRTC_HOME/iot/certs

./install-aws-cli.sh
./build-kvs-webrtc.sh

cd ./iot
./provision-thing.sh
cd ..

./install-kvs-webrtc-service.sh

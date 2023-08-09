#!/bin/bash

if [[ -z $AWS_ACCESS_KEY_ID || -z $AWS_SECRET_ACCESS_KEY || -z $AWS_DEFAULT_REGION ]]; then
  echo 'AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY and AWS_DEFAULT_REGION must be set'
  exit 1
fi

./install-aws-cli.sh
./build-kvs-webrtc.sh

cd ./iot
./provision-thing.sh
cd ..

./install-kvs-webrtc-service.sh

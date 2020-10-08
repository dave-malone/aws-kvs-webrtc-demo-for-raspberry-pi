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


# generate run-kvs-webrtc.sh using outputs from previous setps

cat > run-kvs-webrtc.sh <<EOF
export AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION

export AWS_IOT_CREDENTIALS_ENDPOINT=`cat ./iot/credential-provider-endpoint`
export AWS_IOT_ROLE_ALIAS=`cat ./iot/role-alias`

export IOT_CERT_PATH=$PWD/iot/certs/device.cert.pem
export IOT_PRIVATE_KEY_PATH=$PWD/iot/certs/device.private.key
export IOT_CA_CERT_PATH=$PWD/iot/certs/root-CA.crt
export AWS_KVS_CACERT_PATH=$PWD/amazon-kinesis-video-streams-webrtc-sdk-c/certs/cert.pem

export LD_LIBRARY_PATH=$PWD/amazon-kinesis-video-streams-webrtc-sdk-c/open-source/lib/:$PWD/amazon-kinesis-video-streams-webrtc-sdk-c/build/
./amazon-kinesis-video-streams-webrtc-sdk-c/build/kvsWebrtcClientMasterGstSample `cat ./iot/thing-name`
EOF

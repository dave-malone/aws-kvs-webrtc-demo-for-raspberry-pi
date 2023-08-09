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

# generate run-kvs-webrtc.sh using outputs from previous setps
cat > ./amazon-kinesis-video-streams-webrtc-sdk-c/run-kvs-webrtc-client-master-sample.sh <<EOF
export AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION

export AWS_IOT_CREDENTIALS_ENDPOINT=`cat $(pwd)/amazon-kinesis-video-streams-webrtc-sdk-c/iot/credential-provider-endpoint`
export AWS_IOT_ROLE_ALIAS=`cat $(pwd)/amazon-kinesis-video-streams-webrtc-sdk-c/iot/role-alias`

export IOT_CERT_PATH=`$KVS_WEBRTC_HOME`/iot/certs/device.cert.pem
export IOT_PRIVATE_KEY_PATH=`$KVS_WEBRTC_HOME`/iot/certs/device.private.key
export IOT_CA_CERT_PATH=`$KVS_WEBRTC_HOME`/iot/certs/root-CA.crt
export AWS_KVS_CACERT_PATH=`$KVS_WEBRTC_HOME`/certs/cert.pem

export DEBUG_LOG_SDP=TRUE
export AWS_KVS_LOG_LEVEL=1

`$KVS_WEBRTC_HOME`/build/samples/kvsWebrtcClientMasterGstSample `cat $(pwd)/amazon-kinesis-video-streams-webrtc-sdk-c/iot/thing-name`
EOF

sudo chmod 755 ./run-kvs-webrtc-client-master-sample.sh

echo "moving amazon-kinesis-video-streams-webrtc-sdk-c to /opt/"
sudo mv ./amazon-kinesis-video-streams-webrtc-sdk-c/* $KVS_WEBRTC_HOME

./install-kvs-webrtc-service.sh

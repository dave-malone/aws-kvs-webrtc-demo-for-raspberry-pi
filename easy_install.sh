#!/bin/bash

if [[ -z $AWS_ACCESS_KEY_ID || -z $AWS_SECRET_ACCESS_KEY || -z $AWS_DEFAULT_REGION ]]; then
  echo 'AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY and AWS_DEFAULT_REGION must be set'
  exit 1
fi

export THING_NAME=$1

if [[ -z $THING_NAME ]]; then
  # prompt for thing name
  echo -n "Enter a Name for your IoT Thing: "
  read THING_NAME
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
echo "generating run-kvs-webrtc-client-master-sample.sh under $(pwd)/amazon-kinesis-video-streams-webrtc-sdk-c"
cat > ./amazon-kinesis-video-streams-webrtc-sdk-c/run-kvs-webrtc-client-master-sample.sh <<EOF
KVS_SDK_HOME=$KVS_WEBRTC_HOME

export AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION
export AWS_IOT_CORE_CREDENTIAL_ENDPOINT=`cat $(pwd)/amazon-kinesis-video-streams-webrtc-sdk-c/iot/credential-provider-endpoint`
export AWS_IOT_CORE_ROLE_ALIAS=`cat $(pwd)/amazon-kinesis-video-streams-webrtc-sdk-c/iot/role-alias`
export AWS_IOT_CORE_THING_NAME=`cat $(pwd)/amazon-kinesis-video-streams-webrtc-sdk-c/iot/thing-name`

export AWS_IOT_CORE_CERT=\$KVS_SDK_HOME/iot/certs/device.cert.pem
export AWS_IOT_CORE_PRIVATE_KEY=\$KVS_SDK_HOME/iot/certs/device.private.key
export IOT_CA_CERT_PATH=\$KVS_SDK_HOME/iot/certs/root-CA.crt
export AWS_KVS_CACERT_PATH=\$KVS_SDK_HOME/certs/cert.pem

export DEBUG_LOG_SDP=TRUE
export AWS_KVS_LOG_LEVEL=1
export AWS_ENABLE_FILE_LOGGING=TRUE

\$KVS_SDK_HOME/build/samples/kvsWebrtcClientMasterGstSample `cat $(pwd)/amazon-kinesis-video-streams-webrtc-sdk-c/iot/thing-name`
EOF

sudo chmod 755 ./amazon-kinesis-video-streams-webrtc-sdk-c/run-kvs-webrtc-client-master-sample.sh

echo "moving amazon-kinesis-video-streams-webrtc-sdk-c to /opt/"
sudo cp -r $(pwd)/amazon-kinesis-video-streams-webrtc-sdk-c/* $KVS_WEBRTC_HOME

./install-kvs-webrtc-service.sh

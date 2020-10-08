# Amazon Kinesis Video Streams WebRTC Demo for Raspberry Pi Devices

Demo assets and instructions to get started with WebRTC using Amazon Kinesis Video Streams on Raspberry Pi devices.

Requires an AWS account and a Raspberry Pi

# How to use this on your Raspberry Pi

Create a temporary AWS key pair, and set these as environment variables on your Pi. These will only be used to provision your initial set of AWS Cloud resources and can be discarded after the subsequent steps have successfully completed.

```
export AWS_ACCESS_KEY_ID= <AWS account access key>
export AWS_SECRET_ACCESS_KEY= <AWS account secret key>
```

Clone this repo:

`git clone https://github.com/dave-malone/aws-kvs-webrtc-demo-for-raspberry-pi`

Run the easy install script. Please note that this script will install packages on your Raspberry Pi, will clone and build the amazon-kinesis-video-streams-webrtc-sdk-c, and will also provision AWS Cloud resources on your behalf. Installing packages and building the webrtc sdk will take some time, so please be patient.

```
cd aws-kvs-webrtc-demo-for-raspberry-pi
./easy_install.sh
```

Upon successful completion, a script named `run-kvs-webrtc.sh` will have been generated, which can be used to launch the KVS WebRTC sample applications.

In order to execute `run-kvs-webrtc.sh`, you will need to first run `chmod +x ./run-kvs-webrtc.sh`

# Amazon Kinesis Video Streams WebRTC Demo for Raspberry Pi Devices

Demo assets and instructions to get started with WebRTC using Amazon Kinesis Video Streams on Raspberry Pi devices.

Requires an AWS account and a Raspberry Pi

## Raspberry Pi Setup

Before you begin, if you are going to use a Raspberry Pi Camera, follow these instructions to first ensure that your camera is configured correctly:

https://picamera.readthedocs.io/en/latest/quickstart.html

Additionally, it is encouraged to update your Raspberry Pi and to verify that the git utility is installed prior to proceeding:

```
sudo apt update
sudo apt install git -y
```

## How to use this on your Raspberry Pi

Create a temporary AWS key pair, and set these as environment variables on your Pi. These will only be used to provision your initial set of AWS Cloud resources and can be discarded after the subsequent steps have successfully completed.

```
export AWS_ACCESS_KEY_ID= <AWS account access key>
export AWS_SECRET_ACCESS_KEY= <AWS account secret key>
export AWS_DEFAULT_REGION=us-east-1
```

Clone this repo:

`git clone https://github.com/dave-malone/aws-kvs-webrtc-demo-for-raspberry-pi`

Run the easy install script. Please note that this script will install packages on your Raspberry Pi, will clone and build the amazon-kinesis-video-streams-webrtc-sdk-c, and will also provision AWS Cloud resources on your behalf. Installing packages and building the webrtc sdk will take some time, so please be patient.

```
cd aws-kvs-webrtc-demo-for-raspberry-pi
./easy_install.sh
```

Upon successful completion, a script named `run-kvs-webrtc.sh` will have been generated, which can be used to launch the KVS WebRTC sample applications.

In order to execute `run-kvs-webrtc.sh`, you will need to make the file executable, like this: `chmod +x ./run-kvs-webrtc.sh`

Once the demo program is working, you can login to your AWS Console, navigate to Kinesis Video Streams > Signaling channels, and click the link for the signaling channel with the same name you provided to your IoT Thing during the `easy_install` process. This will allow you to view your camera's live feed in the browser to verify that everything is working as expected.

You can replace the default Amazon KVS for WebRTC library and specify a specific branch by setting the optional environment variables below:

```
export AWS_KVS_WEBRTC_SDK= <git clone url for SDK>
export AWS_KVS_WEBRTC_SDK_BRANCH= <git branch name for SDK>
```

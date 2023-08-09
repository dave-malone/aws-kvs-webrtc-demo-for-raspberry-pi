# Amazon Kinesis Video Streams for WebRTC Demo for Raspberry Pi Devices

Demo assets and instructions to quickly get started with WebRTC using Amazon Kinesis Video Streams on Raspberry Pi devices.

Requires an AWS account and a Raspberry Pi

## Raspberry Pi Setup

Before you begin, if you are going to use a Raspberry Pi Camera, follow these instructions to first ensure that your camera is configured correctly:

https://picamera.readthedocs.io/en/latest/quickstart.html

Additionally, it is encouraged to update your Raspberry Pi and to verify that the git utility is installed prior to proceeding:

```
sudo apt update
sudo apt install git -y
```

## Obtain AWS credentials

The scripts in this project make use of the AWS CLI in order to provision resources into your AWS account. To use these scripts, create a temporary AWS key pair and set these as environment variables on your Pi. These will only be used to provision your initial set of AWS Cloud resources and can be discarded after the subsequent steps have successfully completed. Follow these instructions to create an AWS access key: https://repost.aws/knowledge-center/create-access-key.

Then, set your AWS access key as environment variables in your Raspberry Pi device:

```
export AWS_ACCESS_KEY_ID= <AWS account access key>
export AWS_SECRET_ACCESS_KEY= <AWS account secret key>
export AWS_DEFAULT_REGION=us-east-1
```

## Using this repostiory to provision your Raspberry Pi for use with Amazon Kinesis Video Streams for WebRTC

Clone this repo:

`git clone --recurse-submodules https://github.com/dave-malone/aws-kvs-webrtc-demo-for-raspberry-pi`

Run the easy install script. Please note that this script will install packages on your Raspberry Pi, will clone and build the amazon-kinesis-video-streams-webrtc-sdk-c, and will also provision AWS Cloud resources on your behalf. Installing packages and building the webrtc sdk will take some time, so please be patient.

The `easy_install` script can be passed the AWS IoT Core Thing Name as an argument. If you do not set this, the script will prompt and wait for you to enter a Thing Name before proceeding. 

```
cd aws-kvs-webrtc-demo-for-raspberry-pi
./easy_install.sh YOUR_THING_NAME
```

Upon successful completion, a new service named `kvs-webrtc.service` will be registered. You can check the status of this service by running the following command: `sudo systemctl start kvs-webrtc.service`. The sample applications have been installed under `/opt/amazon-kinesis-video-streams-webrtc-sdk-c`. 

Once the demo program is working, you can login to your AWS Console, navigate to Kinesis Video Streams > Signaling channels, and click the link for the signaling channel with the same name you provided to your IoT Thing during the `easy_install` process. This will allow you to view your camera's live feed in the browser to verify that everything is working as expected.

## Clean up 

Ensure that you have deleted the AWS access key pair used to initially provision your Raspberry Pi device, as it is no longer needed. 

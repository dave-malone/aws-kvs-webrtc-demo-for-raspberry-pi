# Amazon Kinesis Video Streams for WebRTC Demo for Raspberry Pi Devices

Demo assets and instructions to quickly get started with WebRTC using Amazon Kinesis Video Streams on Raspberry Pi devices.

Requires an AWS account and a Raspberry Pi with a camera attached.

## What does this repo do?

This repository contains mostly bash scripts that you can use to build the [Amazon Kinesis Video Streams for WebRTC SDK for C](https://github.com/awslabs/amazon-kinesis-video-streams-webrtc-sdk-c). The scripts will perform the following tasks:

* Installs the AWS CLI (used to help with initial AWS IoT Core provisioning)
* Installs development and runtime dependencies for the SDK 
* Patch some of the files in the SDK
* Compiles the SDK and sample applications
* Provision your Raspberry Pi as an AWS IoT Core Thing
* Generates a "run" script for the SDK sample applications
* Configures a systemctl service so the application can be managed via systemd services

## Raspberry Pi Setup

To begin, setup your Raspberry Pi. You can follow these instructions if you do not know how to perform the necessary steps: https://projects.raspberrypi.org/en/projects/raspberry-pi-setting-up. The easiest way to get started is to use the Raspberry Pi Imager, which is available for download here: https://www.raspberrypi.com/software/

Once you have your Raspberry Pi device configured and connected to your network, follow these instructions to ensure that your camera is configured correctly: https://picamera.readthedocs.io/en/latest/quickstart.html.

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

Upon successful completion, a new service named `kvs-webrtc.service` will be registered. You can check the status of this service by running the following command: 
`sudo systemctl status kvs-webrtc.service`. 

The sample applications have been installed under `/opt/amazon-kinesis-video-streams-webrtc-sdk-c`. The service will direct Stdout and Stderror logs to `/var/log/kvs-webrtc.log`, and service specific logs are in the usual `tail -f /var/log/syslog` file.

Once the demo program is working, you can login to your AWS Console, navigate to Kinesis Video Streams > Signaling channels, and click the link for the signaling channel with the same name you provided to your IoT Thing during the `easy_install` process. This will allow you to view your camera's live feed in the browser to verify that everything is working as expected.

## Test your camera device

As long as your Raspberry Pi shows that the service is successfully running (see steps above), you can navigate to the KVS WebRTC Test Page, enter in your AWS region, AWS credentials, and the name of your device used in the previous steps, and click the "Start Viewer" button. If everything is working, you will be able to view a live feed from your camera!

https://awslabs.github.io/amazon-kinesis-video-streams-webrtc-sdk-js/examples/index.html

## Clean up 

Ensure that you have deleted the AWS access key pair used to initially provision your Raspberry Pi device, as it is no longer needed. 

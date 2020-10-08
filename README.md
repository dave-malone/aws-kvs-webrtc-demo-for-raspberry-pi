Bryan Neff's writeup: https://amazon.awsapps.com/workdocs/index.html#/document/7c69d8142bcc50cd30f6827a42c9320d7906634e1db441bd5626551e2e7af100



sudo apt-get install libgstreamer1.0-0 gstreamer1.0-plugins-base \
  libgstreamer-plugins-base1.0-dev gstreamer1.0-plugins-good gstreamer1.0-plugins-bad \
  gstreamer1.0-plugins-ugly gstreamer1.0-libav gstreamer1.0-doc gstreamer1.0-tools \
  gstreamer1.0-x gstreamer1.0-alsa gstreamer1.0-gl gstreamer1.0-gtk3 gstreamer1.0-pulseaudio



"v4l2src do-timestamp=TRUE device=\"/dev/video0\" ! queue ! videoflip method=rotate-180 ! videoconvert ! video/x-raw,format=I420,width=640,height=480,framerate=30/1 ! omxh264enc control-rate=1 target-bitrate=500000 periodicty-idr=30 inline-header=FALSE ! h264parse config-interval=-1 ! video/x-h264,stream-format=byte-stream,alignment=au,width=640,height=480,framerate=30/1,profile=baseline ! appsink sync=TRUE emit-signals=TRUE name=appsink-video",


changes made in Common.c, kvsWebRTCClientMasterGstreamerSample.c


```
aws iot describe-endpoint --endpoint-type iot:CredentialProvider
```


Instructions from: https://docs.aws.amazon.com/kinesisvideostreams/latest/dg/how-iot.html

TODO - can we make this a quick CloudFormation template?

```
aws --profile default  iam create-role \
  --role-name KVSCameraCertificateBasedIAMRole \
  --assume-role-policy-document 'file://iam-policy-document.json' > iam-role.json

aws --profile default iam put-role-policy \
  --role-name KVSCameraCertificateBasedIAMRole \
  --policy-name KVSCameraIAMPolicy \
  --policy-document 'file://iam-permission-document.json'



aws --profile default iot create-role-alias \
  --role-alias KvsCameraIoTRoleAlias \
  --role-arn $(jq --raw-output '.Role.Arn' iam-role.json) \
  --credential-duration-seconds 3600 > iot-role-alias.json


aws --profile default iot create-policy \
  --policy-name KvsCameraIoTPolicy \
  --policy-document 'file://iot-policy-document.json'

```

Bryan Neff's writeup: https://amazon.awsapps.com/workdocs/index.html#/document/7c69d8142bcc50cd30f6827a42c9320d7906634e1db441bd5626551e2e7af100

"v4l2src do-timestamp=TRUE device=\"/dev/video0\" ! queue ! videoflip method=rotate-180 ! videoconvert ! video/x-raw,format=I420,width=640,height=480,framerate=30/1 ! omxh264enc control-rate=1 target-bitrate=500000 periodicty-idr=30 inline-header=FALSE ! h264parse config-interval=-1 ! video/x-h264,stream-format=byte-stream,alignment=au,width=640,height=480,framerate=30/1,profile=baseline ! appsink sync=TRUE emit-signals=TRUE name=appsink-video",


changes made in Common.c, kvsWebRTCClientMasterGstreamerSample.c

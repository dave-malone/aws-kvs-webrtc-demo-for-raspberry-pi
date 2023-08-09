#!/bin/bash

systemctl stop kvs-webrtc.service
systemctl disable kvs-webrtc.service
rm /etc/systemd/system/kvs-webrtc.service
systemctl daemon-reload
systemctl reset-failed

rm -rf /opt/amazon-kinesis-video-streams-webrtc-sdk-c

# uninstall AWS resources?
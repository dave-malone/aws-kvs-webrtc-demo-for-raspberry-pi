cp ./kvs-webrtc.service /etc/systemd/system/kvs-webrtc.service

sudo chmod 755 /home/pi/amazon-kinesis-video-streams-webrtc-sdk-c/run-kvs-webrtc.sh
sudo systemctl daemon-reload
sudo systemctl enable kvs-webrtc.service
sudo systemctl start kvs-webrtc.service

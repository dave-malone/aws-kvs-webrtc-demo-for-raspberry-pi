https://hub.docker.com/r/balenalib/raspberry-pi-debian


docker pull balenalib/raspberry-pi-debian
docker run -it balenalib/raspberry-pi-debian /bin/bash

#sudo apt-get update

install_packages vim git
install_packages libssl-dev libcurl4-openssl-dev liblog4cplus-dev libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev gstreamer1.0-plugins-base-apps gstreamer1.0-plugins-bad gstreamer1.0-plugins-good gstreamer1.0-plugins-ugly gstreamer1.0-tools
install_packages cmake zip
install_packages build-essential

git clone --recursive https://github.com/dave-malone/amazon-kinesis-video-streams-webrtc-sdk-c

mkdir -p amazon-kinesis-video-streams-webrtc-sdk-c/build
cd amazon-kinesis-video-streams-webrtc-sdk-c/build
cmake .. -DBUILD_TEST=TRUE
make

cd ..

zip -r kvs-webrtc-sdk-c-rpi-zero-build ./build/* ./open-source/* ./certs/*


Copy the zip file from the running Docker container:

docker ps

docker cp c0ee80493331:/amazon-kinesis-video-streams-webrtc-sdk-c/kvs-webrtc-sdk-c-rpi-zero-build.zip ~/Desktop

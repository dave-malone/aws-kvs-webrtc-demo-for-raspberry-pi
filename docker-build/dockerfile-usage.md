
First, build the Docker image:
```
docker build -t rpi-kvs-webrtc-builder .
```

Once built, you can run the container and use it to build software for the Raspberry Pi:
```
docker run -it rpi-kvs-webrtc-builder /bin/bash
```

Then within the running Docker container:

(started at ~8:10 am)
(finished at ~)

```
git clone --recursive https://github.com/dave-malone/amazon-kinesis-video-streams-webrtc-sdk-c

mkdir -p amazon-kinesis-video-streams-webrtc-sdk-c/build
cd amazon-kinesis-video-streams-webrtc-sdk-c/build
cmake .. -DBUILD_TEST=TRUE
make

cd ..

zip -r kvs-webrtc-sdk-c-rpi-zero-build ./build/* ./open-source/* ./certs/*

```

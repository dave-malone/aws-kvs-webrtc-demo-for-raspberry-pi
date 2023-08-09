sudo cp ./kvs-webrtc.service /etc/systemd/system/kvs-webrtc.service

# generate run-kvs-webrtc.sh using outputs from previous setps
cat > ./run-kvs-webrtc-client-master-sample.sh <<EOF
export AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION

export AWS_IOT_CREDENTIALS_ENDPOINT=`cat $KVS_WEBRTC_HOME/iot/credential-provider-endpoint`
export AWS_IOT_ROLE_ALIAS=`cat $KVS_WEBRTC_HOME/iot/role-alias`

export IOT_CERT_PATH=`$KVS_WEBRTC_HOME/iot/certs/device.cert.pem`
export IOT_PRIVATE_KEY_PATH=`$KVS_WEBRTC_HOME/iot/certs/device.private.key`
export IOT_CA_CERT_PATH=`$KVS_WEBRTC_HOME/iot/certs/root-CA.crt`
export AWS_KVS_CACERT_PATH=`$KVS_WEBRTC_HOME/certs/cert.pem`

export DEBUG_LOG_SDP=TRUE
export AWS_KVS_LOG_LEVEL=1

`$KVS_WEBRTC_HOME/build/samples/kvsWebrtcClientMasterGstSample` `cat $KVS_WEBRTC_HOME/iot/thing-name`
EOF

sudo chmod 755 ./run-kvs-webrtc-client-master-sample.sh
sudo mv ./run-kvs-webrtc-client-master-sample.sh $KVS_WEBRTC_HOME/

sudo systemctl daemon-reload
sudo systemctl enable kvs-webrtc.service
sudo systemctl start kvs-webrtc.service

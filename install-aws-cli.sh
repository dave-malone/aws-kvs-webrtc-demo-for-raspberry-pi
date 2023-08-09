#!/bin/bash

if ! type "aws" > /dev/null; then
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip awscliv2.zip
  sudo ./aws/install
  rm -rf ./aws
  rm -f awscliv2.zip
fi

aws --version

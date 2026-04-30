#!/bin/bash
set -e

echo "Installing Java..."

# Amazon Linux 2
sudo yum update -y
sudo yum install -y java-17-amazon-corretto

echo "Java installed successfully"
java -version

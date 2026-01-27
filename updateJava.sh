#!/bin/bash
# Install Java 21
sudo apt-get update
sudo apt-get install -y openjdk-21-jre-headless

# Update Jenkins to use Java 21
sudo sed -i 's|JAVA_HOME=.*|JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64|' /etc/default/jenkins

# Restart Jenkins
sudo systemctl restart jenkins

echo "✅ Java 21 installed and Jenkins updated"

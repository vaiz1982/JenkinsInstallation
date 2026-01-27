# Install Java 21
sudo apt-get update
sudo apt-get install -y openjdk-21-jre-headless

# Update Jenkins to use Java 21
sudo nano /etc/default/jenkins
# Change JAVA_HOME to: /usr/lib/jvm/java-21-openjdk-amd64

# Restart Jenkins
sudo systemctl restart jenkins

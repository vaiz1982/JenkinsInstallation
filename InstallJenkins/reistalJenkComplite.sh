# If above doesn't work, reinstall Jenkins
sudo apt purge jenkins -y
sudo rm -rf /var/lib/jenkins /var/cache/jenkins /etc/jenkins

# Reinstall
sudo apt update
sudo apt install jenkins -y

# Configure before starting
sudo tee /etc/default/jenkins << 'EOF'
NAME=jenkins
JAVA=/usr/bin/java
JAVA_ARGS="-Djava.awt.headless=true -Xmx1024m -Xms512m -XX:+UseG1GC"
JENKINS_ARGS="--webroot=/var/cache/jenkins/war --httpListenAddress=127.0.0.1 --httpPort=8080"
EOF

# Start
sudo systemctl start jenkins
sudo systemctl enable jenkins

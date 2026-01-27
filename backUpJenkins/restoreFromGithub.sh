#!/bin/bash
# restore-jenkins-from-github.sh
GIT_REPO="https://github.com/yourusername/jenkins-backup.git"
GIT_DIR="/opt/jenkins-backup"
JENKINS_HOME="/var/lib/jenkins"

# Stop Jenkins
sudo systemctl stop jenkins

# Clone backup
git clone $GIT_REPO $GIT_DIR

# Find latest backup
LATEST_BACKUP=$(ls -td $GIT_DIR/jenkins-backup-* | head -1)

# Restore
sudo cp -r $LATEST_BACKUP/jobs $JENKINS_HOME/
sudo cp $LATEST_BACKUP/*.xml $JENKINS_HOME/
sudo cp $LATEST_BACKUP/plugins/*.jpi $JENKINS_HOME/plugins/

# Fix permissions
sudo chown -R jenkins:jenkins $JENKINS_HOME

# Start Jenkins
sudo systemctl start jenkins

echo "✅ Jenkins restored from GitHub backup"

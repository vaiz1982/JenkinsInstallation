#!/bin/bash
# backup-jenkins-to-github.sh
BACKUP_DIR="/tmp/jenkins-backup-$(date +%Y%m%d-%H%M%S)"
GIT_REPO="https://github.com/yourusername/jenkins-backup.git"
GIT_DIR="/opt/jenkins-backup"

# 1. Create backup
mkdir -p $BACKUP_DIR
cp -r /var/lib/jenkins/jobs $BACKUP_DIR/
cp /var/lib/jenkins/config.xml $BACKUP_DIR/
cp /var/lib/jenkins/*.xml $BACKUP_DIR/
mkdir -p $BACKUP_DIR/plugins
cp /var/lib/jenkins/plugins/*.jpi $BACKUP_DIR/plugins/

# 2. Clone or init git repo
if [ ! -d "$GIT_DIR/.git" ]; then
    git clone $GIT_REPO $GIT_DIR
else
    cd $GIT_DIR
    git pull
fi

# 3. Copy backup to git repo
cp -r $BACKUP_DIR/* $GIT_DIR/

# 4. Push to GitHub
cd $GIT_DIR
git add .
git commit -m "Jenkins backup $(date)"
git push origin main

# 5. Cleanup
rm -rf $BACKUP_DIR

echo "✅ Jenkins backup pushed to GitHub"

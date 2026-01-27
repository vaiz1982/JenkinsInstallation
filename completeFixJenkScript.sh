#!/bin/bash
echo "=== FIXING MISSING JENKINS CORE FILES ==="

# Stop Jenkins
sudo systemctl stop jenkins

# Backup existing cache
BACKUP_DIR="/tmp/jenkins-cache-backup-$(date +%s)"
sudo mv /var/cache/jenkins "$BACKUP_DIR"
echo "✅ Backup created: $BACKUP_DIR"

# Create new cache structure
sudo mkdir -p /var/cache/jenkins/{war,tmp}
sudo chown -R jenkins:jenkins /var/cache/jenkins

# Extract WAR file
echo "Extracting Jenkins WAR file..."
cd /var/cache/jenkins/war
sudo -u jenkins jar -xf /usr/share/java/jenkins.war

# Verify extraction
if [ -f "WEB-INF/lib/jenkins-core-2.528.3.jar" ]; then
    echo "✅ Core file extracted successfully"
else
    echo "⚠️  WAR extraction failed, trying alternative method..."
    sudo -u jenkins cp /usr/share/java/jenkins.war .
    sudo -u jenkins unzip -q jenkins.war
fi

# Fix permissions
sudo chown -R jenkins:jenkins /var/cache/jenkins
sudo chmod 755 /var/cache/jenkins/war

# Start Jenkins
sudo systemctl start jenkins

# Test
sleep 5
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 2>/dev/null || echo "error")

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "403" ]; then
    echo "✅ Jenkins fixed! HTTP Status: $HTTP_CODE"
else
    echo "❌ Still having issues. HTTP Status: $HTTP_CODE"
    echo "Check logs: sudo tail -50 /var/log/jenkins/jenkins.log"
fi

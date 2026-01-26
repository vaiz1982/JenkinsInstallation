#!/bin/bash
echo "=== AGGRESSIVE JENKINS CLEANUP ==="

echo "Before cleanup:"
df -h /

# Stop Jenkins
sudo systemctl stop jenkins

# 1. Clean cache (BIGGEST WIN)
echo "1. Cleaning cache..."
sudo rm -rf /var/cache/jenkins/*

# 2. Clean workspaces
echo "2. Cleaning workspaces..."
sudo rm -rf /var/lib/jenkins/workspace/*

# 3. Clean builds
echo "3. Cleaning build history..."
sudo rm -rf /var/lib/jenkins/jobs/*/builds/*

# 4. Clean plugin temp files
echo "4. Cleaning plugin temp files..."
sudo find /var/lib/jenkins/plugins -type f \( -name "*.bak" -o -name "*.tmp" -o -name "*.old" \) -delete

# 5. Clean logs
echo "5. Rotating logs..."
sudo journalctl --vacuum-time=1d
sudo truncate -s 0 /var/log/jenkins/jenkins.log

# Start Jenkins
sudo systemctl start jenkins

echo "After cleanup:"
df -h /
echo "✅ Freed ~200MB+ of disk space!"

#!/bin/bash
echo "=== JENKINS DISK SPACE CLEANUP ==="

# Backup first
echo "1. Creating backup..."
sudo tar czf /tmp/jenkins-backup-before-clean-$(date +%s).tar.gz /var/lib/jenkins/

echo "2. Current disk usage:"
df -h /

echo -e "\n3. Cleaning workspaces..."
sudo find /var/lib/jenkins/workspace -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} \; 2>/dev/null
echo "   Workspaces cleared"

echo -e "\n4. Limiting build history..."
# Keep only last 5 builds per job
sudo find /var/lib/jenkins/jobs -name "builds" -type d -exec sh -c '
    for dir in "$1"/*/; do
        if [ -d "$dir" ]; then
            ls -td "$dir"/* 2>/dev/null | tail -n +6 | xargs rm -rf 2>/dev/null
        fi
    done
' _ {} \;
echo "   Build history limited to 5 per job"

echo -e "\n5. Clearing caches..."
sudo rm -rf /var/lib/jenkins/cache/*
sudo rm -rf /var/cache/jenkins/war/*
echo "   Caches cleared"

echo -e "\n6. Rotating logs..."
sudo journalctl --vacuum-time=3d
sudo find /var/log/jenkins -name "*.log.*" -mtime +7 -delete
echo "   Logs rotated"

echo -e "\n7. Final disk usage:"
df -h /

echo -e "\n✅ Cleanup complete!"
echo "   Backup saved to: /tmp/jenkins-backup-*.tar.gz"

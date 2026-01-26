sudo bash -c '
echo "🧹 Aggressive Jenkins Cleanup"
echo "Before:" && df -h /

# Stop Jenkins
systemctl stop jenkins

# Clean everything except config
cd /var/lib/jenkins
rm -rf workspace/* cache/* fingerprints/* nodes/* userContent/*
find jobs -name "builds" -type d -exec sh -c "ls -td \"\$1\"/* | tail -n +3 | xargs rm -rf" _ {} \;

# Clean logs
truncate -s 0 /var/log/jenkins/jenkins.log
find /var/log/jenkins -name "*.log.*" -delete
journalctl --vacuum-time=1d

# Start Jenkins
systemctl start jenkins

echo "After:" && df -h /
echo "✅ Cleanup done!"


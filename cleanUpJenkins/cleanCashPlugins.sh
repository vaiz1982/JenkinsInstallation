# 1. Clean the HUGE cache
sudo rm -rf /var/cache/jenkins/*
echo "✅ Freed 106MB from cache"

# 2. Clean plugin backups and temp files
sudo find /var/lib/jenkins/plugins -name "*.bak" -delete
sudo find /var/lib/jenkins/plugins -name "*.tmp" -delete
sudo find /var/lib/jenkins/plugins -name "*.old" -delete

# 3. Clean workspace (optional - 896KB)
sudo rm -rf /var/lib/jenkins/workspace/*

# 4. Clean update center cache
sudo rm -rf /var/lib/jenkins/updates/*

# 5. Clean build history (172KB + 72KB)
sudo rm -rf /var/lib/jenkins/jobs/*/builds/*

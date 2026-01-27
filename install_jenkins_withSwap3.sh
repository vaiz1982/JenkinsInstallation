#!/bin/bash
# Complete Jenkins + Nginx Fix - Start to Finish
# Usage: sudo ./install_jenkins_final.sh

set -e

echo "========================================"
echo "     JENKINS + NGINX FINAL INSTALL"
echo "========================================"

# --------------------------------------------------
# STEP 1: UPDATE SYSTEM
# --------------------------------------------------
echo "[1/8] Updating system..."
apt-get update
apt-get upgrade -y
apt-get install -y curl wget net-tools

# --------------------------------------------------
# STEP 2: CLEAN UP EXISTING
# --------------------------------------------------
echo "[2/8] Cleaning up existing installation..."
systemctl stop jenkins 2>/dev/null || true
systemctl stop nginx 2>/dev/null || true

# Remove Jenkins if exists
if dpkg -l | grep -q jenkins; then
    apt-get remove --purge -y jenkins
fi

# Remove Nginx configs
rm -f /etc/nginx/sites-enabled/jenkins 2>/dev/null || true
rm -f /etc/nginx/sites-available/jenkins 2>/dev/null || true
rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true

# Clean directories
rm -rf /var/lib/jenkins /var/cache/jenkins /var/log/jenkins 2>/dev/null || true

# --------------------------------------------------
# STEP 3: INSTALL JAVA
# --------------------------------------------------
echo "[3/8] Installing Java..."
apt-get install -y openjdk-17-jre-headless

# --------------------------------------------------
# STEP 4: INSTALL JENKINS (DIRECT METHOD)
# --------------------------------------------------
echo "[4/8] Installing Jenkins..."
# Create jenkins user
useradd -r -m -d /var/lib/jenkins jenkins 2>/dev/null || true

# Create directories
mkdir -p /var/lib/jenkins /var/cache/jenkins/war /usr/share/jenkins
chown -R jenkins:jenkins /var/lib/jenkins /var/cache/jenkins

# Download Jenkins WAR
cd /tmp
wget -q https://get.jenkins.io/war-stable/latest/jenkins.war
mv jenkins.war /usr/share/jenkins/
chown jenkins:jenkins /usr/share/jenkins/jenkins.war

# Create systemd service that binds to localhost
cat > /etc/systemd/system/jenkins.service << 'EOF'
[Unit]
Description=Jenkins
After=network.target

[Service]
Type=simple
User=jenkins
Group=jenkins
Environment="JENKINS_HOME=/var/lib/jenkins"
ExecStart=/usr/bin/java -jar /usr/share/jenkins/jenkins.war --webroot=/var/cache/jenkins/war --httpListenAddress=127.0.0.1 --httpPort=8080
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

# --------------------------------------------------
# STEP 5: INSTALL NGINX
# --------------------------------------------------
echo "[5/8] Installing Nginx..."
apt-get install -y nginx

# Remove ALL default/conflicting sites
echo "Removing any conflicting Nginx configurations..."
rm -f /etc/nginx/sites-enabled/* 2>/dev/null || true

# Create Jenkins proxy config
cat > /etc/nginx/sites-available/jenkins << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    
    # Disable logging for cleaner output
    access_log off;
    error_log /var/log/nginx/jenkins-error.log;
    
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host:$server_port;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF

# Remove default symlink if exists
rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true

# Create symlink for Jenkins site
ln -sf /etc/nginx/sites-available/jenkins /etc/nginx/sites-enabled/

# Test configuration
nginx -t

# --------------------------------------------------
# STEP 6: CONFIGURE FIREWALL
# --------------------------------------------------
echo "[6/8] Configuring firewall..."
apt-get install -y ufw

# Reset firewall
echo "y" | ufw --force reset 2>/dev/null || true

# Basic configuration
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 80/tcp
ufw deny 8080/tcp  # Block direct Jenkins access

echo "y" | ufw --force enable

# --------------------------------------------------
# STEP 7: START SERVICES
# --------------------------------------------------
echo "[7/8] Starting services..."

# Start Jenkins
systemctl start jenkins
systemctl enable jenkins

# Start Nginx
systemctl start nginx
systemctl enable nginx

# Wait for services
echo "Waiting for services to start..."
sleep 10

# --------------------------------------------------
# STEP 8: VERIFY INSTALLATION
# --------------------------------------------------
echo "[8/8] Verifying installation..."

echo ""
echo "=== VERIFICATION ==="
echo ""

# Check services
echo "1. Service Status:"
echo "   Jenkins: $(systemctl is-active jenkins)"
echo "   Nginx:   $(systemctl is-active nginx)"

echo ""
echo "2. Listening Ports:"
ss -tlpn | grep -E ":80|:8080" | sort

echo ""
echo "3. Jenkins Process:"
ps aux | grep -E "jenkins|java.*jenkins" | grep -v grep || true

echo ""
echo "4. Nginx Configuration:"
ls -la /etc/nginx/sites-enabled/

echo ""
echo "5. Test Local Access:"
if curl -s http://localhost:8080/login >/dev/null 2>&1; then
    echo "   ✓ Jenkins is accessible locally"
else
    echo "   ✗ Jenkins not accessible locally"
fi

if curl -s http://localhost >/dev/null 2>&1; then
    echo "   ✓ Nginx is serving"
else
    echo "   ✗ Nginx not responding"
fi

echo ""
echo "6. Get Initial Password:"
if [ -f /var/lib/jenkins/secrets/initialAdminPassword ]; then
    echo "   Password: $(cat /var/lib/jenkins/secrets/initialAdminPassword)"
else
    echo "   Password file not ready yet. Check in 30 seconds:"
    echo "   sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
fi

echo ""
echo "=== COMPLETE ==="
SERVER_IP=$(curl -s ifconfig.me)
echo "Access Jenkins at: http://$SERVER_IP/"
echo ""
echo "If you cannot access:"
echo "1. Check firewall: sudo ufw status"
echo "2. Check logs: sudo tail -f /var/log/nginx/error.log"
echo "3. Restart: sudo systemctl restart nginx jenkins"

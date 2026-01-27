#!/bin/bash
# Jenkins + Nginx + Security - ONE-SCRIPT FIX
# Author: Fix-All-The-Things
# Usage: sudo ./install_jenkins_fixed.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}    JENKINS + NGINX INSTALLER          ${NC}"
echo -e "${BLUE}========================================${NC}"

# Get server IP
SERVER_IP=$(curl -s ifconfig.me)
echo "Server IP: $SERVER_IP"
echo ""

# --------------------------------------------------
# STEP 1: COMPLETE CLEANUP
# --------------------------------------------------
echo -e "${YELLOW}[1/7] Cleaning up existing installation...${NC}"
systemctl stop jenkins 2>/dev/null || true
systemctl disable jenkins 2>/dev/null || true
systemctl stop nginx 2>/dev/null || true

# Remove Jenkins completely
apt-get remove --purge -y jenkins 2>/dev/null || true
apt-get autoremove -y 2>/dev/null || true

# Remove configuration files
rm -rf /var/lib/jenkins 2>/dev/null || true
rm -rf /var/cache/jenkins 2>/dev/null || true
rm -rf /var/log/jenkins 2>/dev/null || true
rm -f /etc/default/jenkins 2>/dev/null || true
rm -f /etc/apt/sources.list.d/jenkins.list 2>/dev/null || true
rm -f /usr/share/keyrings/jenkins* 2>/dev/null || true

# Remove Nginx config
rm -f /etc/nginx/sites-enabled/jenkins 2>/dev/null || true
rm -f /etc/nginx/sites-available/jenkins 2>/dev/null || true

# Clean apt
apt-get clean
apt-get update -qq

echo -e "${GREEN}✓ Cleanup complete${NC}"
echo ""

# --------------------------------------------------
# STEP 2: INSTALL JAVA
# --------------------------------------------------
echo -e "${YELLOW}[2/7] Installing Java 17...${NC}"
apt-get install -y openjdk-17-jre-headless
java -version
echo -e "${GREEN}✓ Java installed${NC}"
echo ""

# --------------------------------------------------
# STEP 3: INSTALL JENKINS WITHOUT REPOSITORY ISSUES
# --------------------------------------------------
echo -e "${YELLOW}[3/7] Installing Jenkins...${NC}"

# Create a safe directory for download
cd /tmp

# Remove any existing .deb files
rm -f jenkins*.deb 2>/dev/null || true

# Download the LATEST Jenkins LTS package
echo "Downloading Jenkins package..."
JENKINS_URL="https://get.jenkins.io/debian-stable/jenkins_2.440.3_all.deb"
wget --tries=3 --timeout=30 -q "$JENKINS_URL" -O jenkins.deb

# Check if download succeeded
if [ ! -f jenkins.deb ]; then
    echo -e "${RED}✗ Failed to download Jenkins${NC}"
    echo "Trying alternative URL..."
    wget -q "https://pkg.jenkins.io/debian-stable/binary/jenkins_2.440.3_all.deb" -O jenkins.deb
fi

if [ ! -f jenkins.deb ]; then
    echo -e "${RED}✗ Jenkins download failed. Please check internet connection.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Jenkins package downloaded${NC}"

# Install dependencies first (this prevents conflicts)
echo "Installing dependencies..."
apt-get install -y fontconfig daemon net-tools

# Install Jenkins with non-interactive mode
echo "Installing Jenkins package..."
export DEBIAN_FRONTEND=noninteractive
dpkg -i jenkins.deb 2>/dev/null || true

# Fix any dependencies
apt-get -f install -y

# Verify installation
if [ -f /usr/share/jenkins/jenkins.war ] || [ -f /usr/lib/jenkins/jenkins.war ]; then
    echo -e "${GREEN}✓ Jenkins files installed${NC}"
else
    echo -e "${RED}✗ Jenkins installation failed${NC}"
    echo "Trying one more method..."
    apt-get install -y jenkins 2>/dev/null || true
fi

echo ""

# --------------------------------------------------
# STEP 4: CONFIGURE JENKINS
# --------------------------------------------------
echo -e "${YELLOW}[4/7] Configuring Jenkins...${NC}"

# Backup original config if exists
if [ -f /etc/default/jenkins ]; then
    cp /etc/default/jenkins /etc/default/jenkins.backup
fi

# Create fresh Jenkins configuration
cat > /etc/default/jenkins << 'EOF'
# Jenkins default settings
JENKINS_USER=jenkins
JENKINS_GROUP=jenkins
JENKINS_HOME=/var/lib/jenkins
JAVA_ARGS="-Djava.awt.headless=true -Xmx1024m -Xms512m -XX:+UseG1GC"
JENKINS_ARGS="--webroot=/var/cache/jenkins/war --httpListenAddress=127.0.0.1 --httpPort=8080"
EOF

# Set correct permissions
chown root:root /etc/default/jenkins
chmod 644 /etc/default/jenkins

echo -e "${GREEN}✓ Jenkins configured${NC}"
echo ""

# --------------------------------------------------
# STEP 5: INSTALL AND CONFIGURE NGINX
# --------------------------------------------------
echo -e "${YELLOW}[5/7] Installing and configuring Nginx...${NC}"
apt-get install -y nginx

# Remove default site
rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true

# Create Jenkins proxy configuration
cat > /etc/nginx/sites-available/jenkins << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    
    # Performance
    client_max_body_size 100M;
    proxy_read_timeout 300s;
    proxy_connect_timeout 300s;
    proxy_send_timeout 300s;
    
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host:$server_port;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Port $server_port;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Performance
        proxy_buffering off;
        proxy_request_buffering off;
    }
    
    # Static files caching
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        proxy_pass http://127.0.0.1:8080;
    }
}
EOF

# Enable the site
ln -sf /etc/nginx/sites-available/jenkins /etc/nginx/sites-enabled/

# Test Nginx configuration
nginx -t

echo -e "${GREEN}✓ Nginx configured${NC}"
echo ""

# --------------------------------------------------
# STEP 6: CONFIGURE FIREWALL
# --------------------------------------------------
echo -e "${YELLOW}[6/7] Configuring firewall...${NC}"
apt-get install -y ufw

# Reset firewall
echo "y" | ufw --force reset 2>/dev/null || true

# Configure defaults
ufw default deny incoming
ufw default allow outgoing

# Allow SSH from anywhere (temporarily, you can change this)
ufw allow 22/tcp

# Allow HTTP from anywhere (temporarily)
ufw allow 80/tcp

# Block direct Jenkins access
ufw deny 8080/tcp

# Enable firewall
echo "y" | ufw --force enable

echo -e "${GREEN}✓ Firewall configured${NC}"
echo ""

# --------------------------------------------------
# STEP 7: START SERVICES
# --------------------------------------------------
echo -e "${YELLOW}[7/7] Starting services...${NC}"

# Reload systemd
systemctl daemon-reload

# Start Jenkins
systemctl start jenkins
systemctl enable jenkins

# Start Nginx
systemctl start nginx
systemctl enable nginx

# Wait for Jenkins to start
echo "Waiting for Jenkins to initialize..."
sleep 15

# Check if Jenkins is running
if systemctl is-active --quiet jenkins; then
    echo -e "${GREEN}✓ Jenkins is running${NC}"
else
    echo -e "${YELLOW}⚠ Jenkins service not active, checking...${NC}"
    systemctl status jenkins --no-pager | head -20
    echo "Trying to restart..."
    systemctl restart jenkins
    sleep 5
fi

# --------------------------------------------------
# FINAL OUTPUT
# --------------------------------------------------
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}         INSTALLATION COMPLETE!         ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${GREEN}✅ Services Status:${NC}"
echo "Jenkins: $(systemctl is-active jenkins)"
echo "Nginx:   $(systemctl is-active nginx)"
echo ""
echo -e "${GREEN}🌐 Access URLs:${NC}"
echo "Main URL:    http://$SERVER_IP/"
echo "Jenkins URL: http://$SERVER_IP:8080/ (local only)"
echo ""
echo -e "${GREEN}🔑 Initial Admin Password:${NC}"

# Try multiple times to get the password
for i in {1..10}; do
    if [ -f /var/lib/jenkins/secrets/initialAdminPassword ]; then
        PASSWORD=$(cat /var/lib/jenkins/secrets/initialAdminPassword)
        echo "$PASSWORD"
        echo "(File: /var/lib/jenkins/secrets/initialAdminPassword)"
        break
    else
        if [ $i -eq 10 ]; then
            echo "Password file not found yet. It may take a moment."
            echo "Run: sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
        fi
        sleep 3
    fi
done

echo ""
echo -e "${GREEN}🔧 Useful Commands:${NC}"
echo "Restart Jenkins:  sudo systemctl restart jenkins"
echo "Restart Nginx:    sudo systemctl restart nginx"
echo "View Jenkins log: sudo tail -f /var/log/jenkins/jenkins.log"
echo "Firewall status:  sudo ufw status"
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Access your Jenkins at: http://$SERVER_IP/${NC}"
echo -e "${BLUE}========================================${NC}"

# Final check
echo ""
echo -e "${YELLOW}Final verification...${NC}"
if curl -s -f http://localhost:8080/login > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Jenkins is accessible locally${NC}"
else
    echo -e "${YELLOW}⚠ Jenkins not responding locally. It may still be starting up.${NC}"
fi

if curl -s -f http://localhost > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Nginx is running${NC}"
else
    echo -e "${YELLOW}⚠ Nginx not responding. Check with: sudo systemctl status nginx${NC}"
fi

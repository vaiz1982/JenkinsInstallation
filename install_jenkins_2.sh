#!/bin/bash
# Jenkins + Nginx + Security Installer for Ubuntu
# Author: Auto-generated from troubleshooting session
# Version: 2.0
# Usage: sudo bash install-jenkins-secure.sh YOUR_ALLOWED_IP

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ALLOWED_IP=${1:-$(curl -s ifconfig.me)}  # Use provided IP or current IP
JENKINS_PORT=8080
NGINX_PORT=80
SWAP_SIZE="2G"
JAVA_MEMORY="-Xmx1024m -Xms512m -XX:+UseG1GC"

# Logging
LOG_FILE="/tmp/jenkins-install-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

print_section() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

print_status() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠  $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then 
        print_error "Please run as root (sudo)"
        exit 1
    fi
}

validate_ip() {
    if [[ ! $ALLOWED_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(/[0-9]+)?$ ]]; then
        print_error "Invalid IP format: $ALLOWED_IP"
        print_error "Use format: 192.168.1.1 or 192.168.1.1/32"
        exit 1
    fi
}

install_dependencies() {
    print_section "Installing Dependencies"
    
    apt-get update -qq
    apt-get install -y -qq \
        apt-transport-https \
        ca-certificates \
        curl \
        software-properties-common \
        gnupg \
        lsb-release
    
    print_status "Dependencies installed"
}

setup_swap() {
    print_section "Setting up Swap Memory"
    
    if [ -f /swapfile ]; then
        print_warning "Swap file already exists, skipping"
        return
    fi
    
    fallocate -l $SWAP_SIZE /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
    sysctl vm.swappiness=10
    sysctl vm.vfs_cache_pressure=50
    
    print_status "Swap memory configured ($SWAP_SIZE)"
}

install_java() {
    print_section "Installing Java"
    
    apt-get install -y -qq openjdk-17-jre-headless
    
    # Verify installation
    java_version=$(java -version 2>&1 | head -1 | awk -F '"' '{print $2}')
    print_status "Java $java_version installed"
}

install_jenkins() {
    print_section "Installing Jenkins"
    
    # Add Jenkins repository
    curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | \
        tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
    echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc]" \
        https://pkg.jenkins.io/debian-stable binary/ | \
        tee /etc/apt/sources.list.d/jenkins.list > /dev/null
    
    apt-get update -qq
    apt-get install -y -qq jenkins
    
    # Configure Jenkins
    cat > /etc/default/jenkins << EOF
NAME=jenkins
JAVA=/usr/bin/java
JAVA_ARGS="-Djava.awt.headless=true $JAVA_MEMORY"
JENKINS_ARGS="--webroot=/var/cache/jenkins/war --httpListenAddress=127.0.0.1 --httpPort=$JENKINS_PORT"
EOF
    
    # Pre-create config to skip wizard (optional)
    mkdir -p /var/lib/jenkins
    cat > /var/lib/jenkins/jenkins.install.InstallUtil.lastExecVersion << EOF
2.0
EOF
    
    print_status "Jenkins installed and configured"
}

install_nginx() {
    print_section "Installing and Configuring Nginx"
    
    apt-get install -y -qq nginx
    
    # Remove default site
    rm -f /etc/nginx/sites-enabled/default
    
    # Create Jenkins reverse proxy config
    cat > /etc/nginx/sites-available/jenkins << EOF
server {
    listen $NGINX_PORT default_server;
    listen [::]:$NGINX_PORT default_server;
    server_name _;
    
    # Performance optimizations
    client_max_body_size 100M;
    proxy_read_timeout 300s;
    proxy_connect_timeout 300s;
    proxy_send_timeout 300s;
    
    location / {
        proxy_pass http://127.0.0.1:$JENKINS_PORT;
        proxy_set_header Host \$host:\$server_port;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port \$server_port;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Performance
        proxy_buffering off;
        proxy_request_buffering off;
        proxy_max_temp_file_size 0;
    }
    
    # Cache static assets
    location ~* \\.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)\$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        proxy_pass http://127.0.0.1:$JENKINS_PORT;
        proxy_set_header Host \$host;
    }
}
EOF
    
    # Enable site
    ln -sf /etc/nginx/sites-available/jenkins /etc/nginx/sites-enabled/
    
    # Test configuration
    nginx -t
    
    print_status "Nginx installed and configured"
}

configure_firewall() {
    print_section "Configuring Firewall"
    
    # Install UFW if not present
    apt-get install -y -qq ufw
    
    # Reset and configure UFW
    ufw --force disable
    ufw --force reset
    
    ufw default deny incoming
    ufw default allow outgoing
    
    # Allow SSH from allowed IP
    ufw allow from $ALLOWED_IP to any port 22
    
    # Allow HTTP from allowed IP only
    ufw allow from $ALLOWED_IP to any port $NGINX_PORT
    
    # Jenkins localhost access only
    ufw allow from 127.0.0.1 to any port $JENKINS_PORT
    ufw deny $JENKINS_PORT/tcp
    
    # Enable firewall
    ufw --force enable
    
    print_status "Firewall configured. Allowing only IP: $ALLOWED_IP"
}

start_services() {
    print_section "Starting Services"
    
    systemctl daemon-reload
    systemctl enable jenkins nginx
    systemctl restart jenkins nginx
    
    # Wait for Jenkins to start
    sleep 10
    
    print_status "Services started"
}

generate_report() {
    print_section "Installation Complete"
    
    SERVER_IP=$(curl -s ifconfig.me)
    JENKINS_PASSWORD=""
    
    if [ -f /var/lib/jenkins/secrets/initialAdminPassword ]; then
        JENKINS_PASSWORD=$(cat /var/lib/jenkins/secrets/initialAdminPassword)
    fi
    
    cat << EOF

${GREEN}═══════════════════════════════════════════════════════════════════════════════${NC}
${GREEN}                    JENKINS INSTALLATION COMPLETE!                            ${NC}
${GREEN}═══════════════════════════════════════════════════════════════════════════════${NC}

${YELLOW}📊 CONFIGURATION SUMMARY:${NC}
   Server IP:           $SERVER_IP
   Allowed Access IP:   $ALLOWED_IP
   Jenkins Port:        $JENKINS_PORT (localhost only)
   Nginx Port:          $NGINX_PORT (public)
   Java Memory:         $JAVA_MEMORY
   Swap Size:           $SWAP_SIZE

${YELLOW}🌐 ACCESS URLs:${NC}
   Jenkins via Nginx:   http://$SERVER_IP/
   Direct Jenkins:      http://localhost:$JENKINS_PORT/ (local only)

${YELLOW}🔐 SECURITY:${NC}
   ✅ Port $NGINX_PORT open only to $ALLOWED_IP
   ✅ Port $JENKINS_PORT blocked externally
   ✅ SSH allowed only from $ALLOWED_IP
   ✅ Jenkins bound to localhost only

${YELLOW}🔑 INITIAL JENKINS PASSWORD:${NC}
   $JENKINS_PASSWORD
   (File: /var/lib/jenkins/secrets/initialAdminPassword)

${YELLOW}🛠️  MANAGEMENT COMMANDS:${NC}
   sudo systemctl restart jenkins nginx
   sudo ufw status
   sudo tail -f /var/log/jenkins/jenkins.log

${YELLOW}📁 LOG FILE:${NC}
   $LOG_FILE

${GREEN}═══════════════════════════════════════════════════════════════════════════════${NC}
${GREEN}      Access Jenkins at: http://$SERVER_IP/                                   ${NC}
${GREEN}═══════════════════════════════════════════════════════════════════════════════${NC}
EOF
}

# Main execution
main() {
    print_section "Jenkins Secure Installation Script"
    echo "Starting installation at $(date)"
    echo "Allowed IP: $ALLOWED_IP"
    
    check_root
    validate_ip
    
    # Installation steps
    install_dependencies
    setup_swap
    install_java
    install_jenkins
    install_nginx
    configure_firewall
    start_services
    
    # Final report
    generate_report
}

# Run main function
main "$@"


#!/bin/bash

set -e

echo "=============================="
echo "🔗 Jenkins GitHub Integration"
echo "=============================="

JENKINS_USER="jenkins"
SSH_DIR="/var/lib/jenkins/.ssh"
KEY_PATH="$SSH_DIR/id_ed25519"

echo "📦 Checking Git..."
if ! command -v git &> /dev/null; then
echo "⬇️ Installing Git..."
sudo apt install -y git
else
echo "✅ Git already installed"
fi

echo "👤 Ensuring Jenkins user SSH directory..."
sudo mkdir -p $SSH_DIR
sudo chown jenkins:jenkins $SSH_DIR
sudo chmod 700 $SSH_DIR

echo "🔑 Checking SSH key..."
if [ ! -f "$KEY_PATH" ]; then
echo "🆕 Creating SSH key for Jenkins..."
sudo -u jenkins ssh-keygen -t ed25519 -f $KEY_PATH -N ""
else
echo "✅ SSH key already exists"
fi

echo "🔓 Setting SSH permissions..."
sudo chown jenkins:jenkins $SSH_DIR/*
sudo chmod 600 $KEY_PATH
sudo chmod 644 $KEY_PATH.pub

echo "📤 Jenkins SSH Public Key (ADD THIS TO GITHUB):"
echo "------------------------------------------------"
sudo cat $KEY_PATH.pub
echo "------------------------------------------------"

echo "🔌 Installing Jenkins Git plugins..."
sudo jenkins-plugin-cli --plugins git github github-branch-source

echo "🔄 Restarting Jenkins..."
sudo systemctl restart jenkins

echo "🧪 Testing GitHub SSH connection..."
sudo -u jenkins ssh -o StrictHostKeyChecking=accept-new [git@github.com](mailto:git@github.com) || true

echo "=============================="
echo "✅ Jenkins ↔ GitHub setup done"
echo "=============================="
echo "➡️ Paste the SSH key above into GitHub:"
echo "GitHub → Settings → SSH and GPG keys"

#!/bin/bash

# Script to create and enable swap space
# Usage: sudo ./swap_setup.sh [size_in_GB]

set -e

# Default swap size if not specified (2GB)
SWAP_SIZE="${1:-2}"
SWAP_FILE="/swapfile"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (use sudo)"
    exit 1
fi

echo "=== Swap Setup Script ==="
echo "System Memory Info:"
free -h
echo ""

# Check if swap already exists
if swapon --show | grep -q .; then
    echo "Swap already exists:"
    swapon --show
    echo -n "Do you want to continue and create additional swap? (y/n): "
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "Exiting..."
        exit 0
    fi
fi

# Validate swap size
if ! [[ "$SWAP_SIZE" =~ ^[0-9]+$ ]]; then
    echo "Error: Swap size must be a number (in GB)"
    exit 1
fi

# Calculate size in MB
SWAP_SIZE_MB=$((SWAP_SIZE * 1024))

echo "Creating ${SWAP_SIZE}GB swap file (${SWAP_SIZE_MB}MB)..."
echo ""

# Create swap file
echo "1. Creating swap file..."
fallocate -l ${SWAP_SIZE}G "$SWAP_FILE" || dd if=/dev/zero of="$SWAP_FILE" bs=1M count="$SWAP_SIZE_MB"

# Set secure permissions
echo "2. Setting permissions..."
chmod 600 "$SWAP_FILE"

# Format as swap
echo "3. Formatting as swap space..."
mkswap "$SWAP_FILE"

# Enable swap
echo "4. Enabling swap..."
swapon "$SWAP_FILE"

# Make permanent
echo "5. Making swap permanent..."
echo "$SWAP_FILE none swap sw 0 0" | tee -a /etc/fstab

# Configure swappiness (optional)
echo "6. Configuring swappiness..."
# Lower swappiness for better performance (10-60 is recommended)
# 10: Prefer RAM, use less swap
# 60: Default Ubuntu value
# 100: Aggressive swapping
SWAPPINESS_VALUE=10

# Current swappiness
echo "Current swappiness: $(cat /proc/sys/vm/swappiness)"

# Set swappiness temporarily
sysctl vm.swappiness="$SWAPPINESS_VALUE"

# Make swappiness permanent
echo "vm.swappiness=$SWAPPINESS_VALUE" | tee -a /etc/sysctl.conf

# Configure cache pressure
echo "vm.vfs_cache_pressure=50" | tee -a /etc/sysctl.conf

# Apply changes
sysctl -p

echo ""
echo "=== Swap Setup Complete ==="
echo ""

# Verify swap is active
echo "Verification:"
echo "1. Swap status:"
swapon --show

echo ""
echo "2. Memory info:"
free -h

echo ""
echo "3. Disk usage:"
df -h "$SWAP_FILE"

echo ""
echo "=== Notes ==="
echo "- Swap file created: $SWAP_FILE"
echo "- Size: ${SWAP_SIZE}GB"
echo "- Swappiness set to: $SWAPPINESS_VALUE"
echo "- Swap is now active and will persist after reboot"

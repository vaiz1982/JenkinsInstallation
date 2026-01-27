#!/bin/bash
# Configure Swap for Jenkins
# Usage: sudo ./configure_swap.sh

set -e

echo "=== Configuring Swap Memory ==="

# --------------------------------------------------
# 1. CHECK CURRENT SWAP
# --------------------------------------------------
echo "1. Current swap status:"
free -h
swapon --show

# --------------------------------------------------
# 2. CREATE SWAP FILE
# --------------------------------------------------
echo ""
echo "2. Creating swap file..."

if [ -f /swapfile ]; then
    echo "Swap file already exists at /swapfile"
    echo "Checking size..."
    ls -lh /swapfile
else
    # Create 2GB swap file (optimal for 2GB RAM)
    echo "Creating 2GB swap file..."
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    
    echo "✅ Swap file created and activated"
fi

# --------------------------------------------------
# 3. MAKE SWAP PERMANENT
# --------------------------------------------------
echo ""
echo "3. Making swap permanent..."

if grep -q "/swapfile" /etc/fstab; then
    echo "Swap already in /etc/fstab"
else
    echo "/swapfile none swap sw 0 0" >> /etc/fstab
    echo "✅ Added to /etc/fstab"
fi

# --------------------------------------------------
# 4. OPTIMIZE SWAP SETTINGS
# --------------------------------------------------
echo ""
echo "4. Optimizing swap settings..."

# Current values
echo "Current vm.swappiness: $(cat /proc/sys/vm/swappiness 2>/dev/null || echo 'Not set')"
echo "Current vm.vfs_cache_pressure: $(cat /proc/sys/vm/vfs_cache_pressure 2>/dev/null || echo 'Not set')"

# Optimize for server with 2GB RAM
# Lower swappiness = use less swap (better for performance)
# Lower vfs_cache_pressure = keep more cache (better for disk I/O)

# Set optimal values
echo "Setting optimal values for Jenkins server..."

# Add to sysctl.conf if not already there
if ! grep -q "vm.swappiness" /etc/sysctl.conf; then
    echo "vm.swappiness=10" >> /etc/sysctl.conf
fi

if ! grep -q "vm.vfs_cache_pressure" /etc/sysctl.conf; then
    echo "vm.vfs_cache_pressure=50" >> /etc/sysctl.conf
fi

# Apply immediately
sysctl -w vm.swappiness=10
sysctl -w vm.vfs_cache_pressure=50

echo "✅ Swap optimized:"
echo "   - swappiness: 10 (use RAM more, swap less)"
echo "   - vfs_cache_pressure: 50 (keep more cache)"

# --------------------------------------------------
# 5. VERIFY AND SHOW RESULTS
# --------------------------------------------------
echo ""
echo "5. Final verification:"

echo "Swap status:"
swapon --show

echo ""
echo "Memory status:"
free -h

echo ""
echo "Disk usage:"
df -h /swapfile 2>/dev/null || df -h /

# --------------------------------------------------
# 6. ADD SWAP MONITORING TO JENKINS (OPTIONAL)
# --------------------------------------------------
echo ""
echo "6. Optional: Add swap monitoring to Jenkins..."

# Create a simple script to monitor swap
cat > /usr/local/bin/check-swap.sh << 'EOF'
#!/bin/bash
echo "=== System Memory Status ==="
echo "Timestamp: $(date)"
echo ""
echo "Memory:"
free -h
echo ""
echo "Swap:"
swapon --show
echo ""
echo "Top memory processes:"
ps aux --sort=-%mem | head -10
EOF

chmod +x /usr/local/bin/check-swap.sh

echo "✅ Swap monitor script created: /usr/local/bin/check-swap.sh"
echo ""
echo "=== COMPLETE ==="
echo "Swap configured successfully!"
echo "Run 'free -h' to see current memory status"
echo "Run '/usr/local/bin/check-swap.sh' to check detailed status"

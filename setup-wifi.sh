#!/bin/bash
# This script runs on boot to update WiFi credentials from a user-editable file
# It is installed and enabled by setup-pi.sh

# Try to find the boot partition
if [ -d "/boot/firmware" ]; then
    CONFIG_FILE="/boot/firmware/wifi-config.txt"
elif [ -d "/boot" ]; then
    CONFIG_FILE="/boot/wifi-config.txt"
else
    echo "ERROR: Cannot find boot partition"
    exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
    echo "No WiFi config file found at $CONFIG_FILE"
    exit 0
fi

SSID=$(grep "^SSID=" "$CONFIG_FILE" | cut -d= -f2 | tr -d '\r')
PASSWORD=$(grep "^PASSWORD=" "$CONFIG_FILE" | cut -d= -f2 | tr -d '\r')

if [ -z "$SSID" ] || [ -z "$PASSWORD" ]; then
    echo "WiFi credentials not found or incomplete"
    exit 0
fi

echo "Updating WiFi configuration for SSID: $SSID"

NETPLAN_CONFIG="/etc/netplan/50-cloud-init.yaml"

# Backup original if not already backed up
if [ ! -f "${NETPLAN_CONFIG}.backup" ]; then
    cp "$NETPLAN_CONFIG" "${NETPLAN_CONFIG}.backup" 2>/dev/null || true
fi

# Create netplan configuration
cat > "$NETPLAN_CONFIG" <<EOF
network:
  version: 2
  wifis:
    wlan0:
      optional: true
      access-points:
        "$SSID":
          password: "$PASSWORD"
      dhcp4: true
EOF

chmod 600 "$NETPLAN_CONFIG"

# Apply netplan configuration
netplan apply

echo "WiFi configuration updated successfully"

echo "WiFi configuration updated successfully"

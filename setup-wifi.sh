#!/bin/bash
# This script runs on boot to update WiFi credentials from a user-editable file
# It is installed and enabled by setup-pi.sh

set -x  # Enable debug logging

# Try to find the boot partition
if [ -d "/boot/firmware" ]; then
    CONFIG_FILE="/boot/firmware/wifi-config.txt"
elif [ -d "/boot" ]; then
    CONFIG_FILE="/boot/wifi-config.txt"
else
    echo "ERROR: Cannot find boot partition"
    exit 1
fi

echo "Looking for config file at: $CONFIG_FILE"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "No WiFi config file found at $CONFIG_FILE"
    ls -la "$(dirname "$CONFIG_FILE")" 2>&1 || true
    exit 0
fi

SSID=$(grep "^SSID=" "$CONFIG_FILE" | cut -d= -f2 | tr -d '\r')
PASSWORD=$(grep "^PASSWORD=" "$CONFIG_FILE" | cut -d= -f2 | tr -d '\r')

echo "Read SSID: $SSID"

if [ -z "$SSID" ] || [ -z "$PASSWORD" ]; then
    echo "WiFi credentials not found or incomplete"
    exit 0
fi

echo "Updating WiFi configuration for SSID: $SSID"

WIFI_CONFIG="/etc/NetworkManager/system-connections/pilookie-wifi.nmconnection"

nmcli connection delete pilookie-wifi 2>/dev/null || true
rm -f "$WIFI_CONFIG"

UUID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "pilookie-$(date +%s)")

cat > "$WIFI_CONFIG" <<EOF
[connection]
id=pilookie-wifi
uuid=$UUID
type=wifi
autoconnect=true
autoconnect-priority=999

[wifi]
ssid=$SSID
mode=infrastructure

[wifi-security]
key-mgmt=wpa-psk
psk=$PASSWORD

[ipv4]
method=auto

[ipv6]
method=auto
EOF

chmod 600 "$WIFI_CONFIG"
chown root:root "$WIFI_CONFIG"

nmcli connection reload

echo "WiFi configuration updated successfully"

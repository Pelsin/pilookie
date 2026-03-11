#!/bin/bash
# This script runs on boot to update WiFi credentials from a user-editable file
# It is installed and enabled by setup-pi.sh

# Unsure if this is needed, but let's try it out
CONFIG_FILE="/boot/firmware/wifi-config.txt"  
WIFI_CONFIG="/etc/NetworkManager/system-connections/pilookie-wifi.nmconnection"

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

# Delete existing connection if it exists
nmcli connection delete pilookie-wifi 2>/dev/null || true

# Create new connection file
tee "$WIFI_CONFIG" > /dev/null <<EOF
[connection]
id=pilookie-wifi
uuid=$(uuidgen)
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

# Reload and activate the connection
nmcli connection reload
sleep 2
nmcli connection up pilookie-wifi

echo "WiFi configuration updated successfully"
echo "Connected to SSID: $SSID"

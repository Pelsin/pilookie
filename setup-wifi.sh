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

if command -v nmcli &> /dev/null; then
    echo "Using NetworkManager..."
    
    nmcli connection delete pilookie-wifi 2>/dev/null || true
    
    nmcli connection add \
        type wifi \
        con-name pilookie-wifi \
        ifname wlan0 \
        ssid "$SSID" \
        wifi-sec.key-mgmt wpa-psk \
        wifi-sec.psk "$PASSWORD" \
        wifi-sec.psk-flags 0 \
        connection.autoconnect yes \
        connection.autoconnect-priority 999
    
    sleep 1
    
    nmcli connection up pilookie-wifi 2>&1 || echo "Connection will activate automatically"
    
elif [ -f /etc/dhcpcd.conf ]; then
    echo "Using dhcpcd/wpa_supplicant..."
    
    # Use wpa_supplicant for dhcpcd-based systems
    WPA_CONF="/etc/wpa_supplicant/wpa_supplicant.conf"
    
    # Backup if not already backed up
    if [ ! -f "${WPA_CONF}.backup" ]; then
        cp "$WPA_CONF" "${WPA_CONF}.backup"
    fi
    
    # Add or update network configuration
    wpa_passphrase "$SSID" "$PASSWORD" >> "$WPA_CONF"
    
    # Reconfigure wpa_supplicant
    wpa_cli -i wlan0 reconfigure
    
else
    echo "ERROR: No supported network manager found"
    exit 1
fi

echo "WiFi configuration updated successfully"

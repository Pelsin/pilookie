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

# Check if NetworkManager is available
if command -v nmcli &> /dev/null; then
    echo "Using NetworkManager..."
    
    # Delete existing connection if it exists
    nmcli connection delete pilookie-wifi 2>/dev/null || true
    
    # Connect using device wifi connect (simpler and more reliable)
    nmcli device wifi connect "$SSID" password "$PASSWORD" name pilookie-wifi
    
    # Set autoconnect priority
    nmcli connection modify pilookie-wifi connection.autoconnect-priority 999
    
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

#!/bin/bash
set -e

echo "Setting up Pilookie on Raspberry Pi..."

if [ "$EUID" -eq 0 ]; then 
   echo "Error: Don't run as root. Run as your normal user."
   exit 1
fi

PROJECT_DIR=$(pwd)
USER=$(whoami)

echo "Setting up WiFi auto-configuration..."
sudo cp "$PROJECT_DIR/setup-wifi.sh" /usr/local/bin/setup-wifi.sh
sudo chmod +x /usr/local/bin/setup-wifi.sh

BOOT_PATH="/boot/firmware"
if [ ! -d "$BOOT_PATH" ]; then
    BOOT_PATH="/boot"
fi

if [ ! -f "$BOOT_PATH/wifi-config.txt" ]; then
    sudo cp "$PROJECT_DIR/wifi-config-template.txt" "$BOOT_PATH/wifi-config.txt"
    echo "WiFi config template copied to $BOOT_PATH/wifi-config.txt"
    echo "Edit this file to change WiFi credentials from your computer"
fi

sudo tee /etc/systemd/system/wifi-setup.service > /dev/null <<EOF
[Unit]
Description=PiLookie WiFi Setup from Boot Partition
DefaultDependencies=no
After=local-fs.target
Before=network-pre.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/setup-wifi.sh
RemainAfterExit=yes

[Install]
WantedBy=sysinit.target
EOF

sudo systemctl enable wifi-setup.service

if ! command -v cloudflared &> /dev/null; then
    echo "Installing cloudflared..."
    cd /tmp
    wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64.deb
    sudo dpkg -i cloudflared-linux-arm64.deb
    rm cloudflared-linux-arm64.deb
    cd "$PROJECT_DIR"
fi

# Find npm and node locations
NPM_PATH=$(which npm)
NODE_PATH=$(which node)
if [ -z "$NPM_PATH" ] || [ -z "$NODE_PATH" ]; then
    echo "Error: npm or node not found. Please install Node.js and npm first."
    exit 1
fi

# Get the bin directory
NODE_BIN_DIR=$(dirname "$NODE_PATH")

echo "Creating systemd services..."
sudo tee /etc/systemd/system/pilookie.service > /dev/null <<EOF
[Unit]
Description=Pilookie Camera Server
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$PROJECT_DIR
Environment=NODE_ENV=production
Environment=PORT=3001
Environment=PATH=$NODE_BIN_DIR:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ExecStart=$NPM_PATH run start
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Read Cloudflare tunnel token from boot partition config
BOOT_PATH="/boot/firmware"
if [ ! -d "$BOOT_PATH" ]; then
    BOOT_PATH="/boot"
fi

if [ -f "$BOOT_PATH/wifi-config.txt" ]; then
    CLOUDFLARE_TUNNEL_TOKEN=$(grep "^CLOUDFLARE_TUNNEL_TOKEN=" "$BOOT_PATH/wifi-config.txt" | cut -d= -f2 | tr -d '\r')
fi

# Check if CLOUDFLARE_TUNNEL_TOKEN is set
if [ -z "$CLOUDFLARE_TUNNEL_TOKEN" ]; then
    echo "Warning: CLOUDFLARE_TUNNEL_TOKEN not set. Using quick tunnel (random URL)."
    TUNNEL_CMD="/usr/local/bin/cloudflared tunnel --url http://localhost:3001"
else
    echo "Using named tunnel with provided token."
    TUNNEL_CMD="/usr/local/bin/cloudflared tunnel run --token $CLOUDFLARE_TUNNEL_TOKEN"
fi

sudo tee /etc/systemd/system/cloudflared-pilookie.service > /dev/null <<EOF
[Unit]
Description=Cloudflare Tunnel for Pilookie
After=network.target pilookie.service
Wants=pilookie.service

[Service]
Type=simple
User=$USER
ExecStart=$TUNNEL_CMD
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable pilookie cloudflared-pilookie
sudo systemctl start pilookie
sleep 3
sudo systemctl start cloudflared-pilookie

echo ""
echo "Setup complete!"
echo ""
echo "View logs:           sudo journalctl -u pilookie -f"
echo "View tunnel logs:    sudo journalctl -u cloudflared-pilookie -f"
echo "Restart services:    sudo systemctl restart pilookie cloudflared-pilookie"
echo ""
echo "Your tunnel URL will appear in the cloudflared logs."
echo ""


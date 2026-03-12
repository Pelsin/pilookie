# Pilookie

A web-based camera control system for managing time-lapse photography with remote access. Built for Raspberry Pi with gphoto2-compatible cameras.

## Production Setup (Raspberry Pi)

1. Copy the project to your Raspberry Pi

2. Install nvm and Node.js:
   ```bash
   curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
   nvm install --lts
   ```

3. Install gphoto2:
   ```bash
   sudo apt-get install gphoto2
   ```

4. Install dependencies:
   ```bash
   npm install
   ```

3. Configure environment variables:
   ```bash
   cp .env.example .env
   # Edit .env with your credentials
   ```

4. Build the project:
   ```bash
   npm run build
   ```

5. Run the setup script:
   ```bash
   chmod +x setup-pi.sh
   ./setup-pi.sh
   ```

## Configuration

### WiFi & Cloudflare Configuration (Headless Setup)

After flashing the SD card, you can easily configure WiFi and Cloudflare tunnel without re-flashing:

1. **Initial Setup**: When running `setup-pi.sh`, a `wifi-config.txt` file is created on the boot partition
2. **To Configure**:
   - Remove SD card from Raspberry Pi
   - Insert into your computer
   - Open the boot partition (appears as `bootfs` or `boot`)
   - Edit `wifi-config.txt`:
     ```
     SSID=YourWiFiName
     PASSWORD=YourWiFiPassword
     
     # Cloudflare Tunnel Token
     # Get your tunnel token from: https://one.dash.cloudflare.com/
     CLOUDFLARE_TUNNEL_TOKEN=your-tunnel-token-here
     ```
   - Eject and insert back into Raspberry Pi
   - The Pi will automatically connect to WiFi and configure the Cloudflare tunnel on boot

The boot partition is FAT32, so it's accessible from Windows, macOS, and Linux.

### Environment Variables

Create a `.env` file with the following variables:

```env
USERNAME=your_username
PASSWORD=your_secure_password
PORT=3001
```

#!/bin/bash

# Raspberry Pi Fotobox WiFi Configuration - Installation Script
# This script automates the installation process

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
print_status() {
    echo -e "${GREEN}[+]${NC} $1"
}

print_error() {
    echo -e "${RED}[!]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[*]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   print_error "This script must be run as root (use sudo)"
   exit 1
fi

print_status "Starting Raspberry Pi Fotobox WiFi Configuration installation..."

# Update system
print_status "Updating system packages..."
apt update
apt upgrade -y

# Install dependencies
print_status "Installing required packages..."
apt install -y python3-pip python3-flask python3-venv chromium-browser

# Install Python packages
print_status "Installing Python dependencies..."
pip3 install flask flask-cors

# Create directory structure
print_status "Creating directory structure..."
mkdir -p /home/pi/wifi-config

# Copy files
print_status "Copying configuration files..."
cp index.html /home/pi/wifi-config/
cp wifi_config_server.py /home/pi/wifi-config/
cp check_connection.sh /home/pi/wifi-config/

# Set permissions
print_status "Setting file permissions..."
chmod +x /home/pi/wifi-config/wifi_config_server.py
chmod +x /home/pi/wifi-config/check_connection.sh
chown -R pi:pi /home/pi/wifi-config

# Create systemd service
print_status "Creating systemd service..."
cp wifi-config.service /etc/systemd/system/

# Create log directory
mkdir -p /var/log
touch /var/log/wifi-config.log
chown pi:pi /var/log/wifi-config.log

# Configure autostart for kiosk mode
print_status "Configuring kiosk mode..."
AUTOSTART_FILE="/home/pi/.config/lxsession/LXDE-pi/autostart"
mkdir -p "$(dirname "$AUTOSTART_FILE")"

# Backup existing autostart if it exists
if [ -f "$AUTOSTART_FILE" ]; then
    cp "$AUTOSTART_FILE" "${AUTOSTART_FILE}.backup"
    print_warning "Backed up existing autostart configuration"
fi

# Create new autostart configuration
cat > "$AUTOSTART_FILE" << EOF
@lxpanel --profile LXDE-pi
@pcmanfm --desktop --profile LXDE-pi
@xscreensaver -no-splash

# Disable screen blanking
@xset s off
@xset -dpms
@xset s noblank

# Start WiFi configuration in kiosk mode
@chromium-browser --kiosk --noerrdialogs --disable-infobars --check-for-update-interval=604800 http://localhost:5000

# Check connection after startup
@/home/pi/wifi-config/check_connection.sh
EOF

chown pi:pi "$AUTOSTART_FILE"

# Enable and start service
print_status "Enabling and starting WiFi configuration service..."
systemctl daemon-reload
systemctl enable wifi-config.service
systemctl start wifi-config.service

# Configure firewall (if ufw is installed)
if command -v ufw &> /dev/null; then
    print_status "Configuring firewall..."
    ufw allow 5000/tcp comment 'WiFi Config'
    ufw allow 3353/tcp comment 'Fotobox'
    ufw --force enable
fi

# Create log rotation config
print_status "Setting up log rotation..."
cat > /etc/logrotate.d/wifi-config << EOF
/var/log/wifi-config.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 pi pi
}
EOF

# Check service status
print_status "Checking service status..."
if systemctl is-active --quiet wifi-config.service; then
    print_status "WiFi configuration service is running successfully!"
else
    print_error "Service failed to start. Check logs with: sudo journalctl -u wifi-config.service"
    exit 1
fi

print_status "Installation completed successfully!"
print_warning "Please reboot your Raspberry Pi to start using the WiFi configuration interface"
print_warning "Run: sudo reboot"

# Optional: Ask if user wants to reboot now
read -p "Do you want to reboot now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_status "Rebooting..."
    reboot
fi

#!/bin/bash

# Raspberry Pi Fotobox WiFi Configuration - Installation Script
# This script automates the installation process

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default configuration values
DEFAULT_WIFI_CONFIG_PORT=5000
DEFAULT_FOTOBOX_URL="http://localhost:3353"
WIFI_CONFIG_PORT=""
FOTOBOX_URL=""

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

print_info() {
    echo -e "${BLUE}[i]${NC} $1"
}

# Function to validate port number
validate_port() {
    local port=$1
    if [[ $port =~ ^[0-9]+$ ]] && [ $port -ge 1 ] && [ $port -le 65535 ]; then
        return 0
    else
        return 1
    fi
}

# Function to validate URL
validate_url() {
    local url=$1
    if [[ $url =~ ^https?://[a-zA-Z0-9.-]+:[0-9]+(/.*)?$ ]] || [[ $url =~ ^https?://[a-zA-Z0-9.-]+(/.*)?$ ]]; then
        return 0
    else
        return 1
    fi
}

# Interactive configuration
configure_installation() {
    echo ""
    print_info "=== Konfiguration der Installation ==="
    echo ""
    
    # WiFi Config Port
    while true; do
        read -p "Port für WiFi-Konfiguration (Standard: $DEFAULT_WIFI_CONFIG_PORT): " input_port
        if [ -z "$input_port" ]; then
            WIFI_CONFIG_PORT=$DEFAULT_WIFI_CONFIG_PORT
            break
        elif validate_port "$input_port"; then
            WIFI_CONFIG_PORT=$input_port
            break
        else
            print_error "Ungültiger Port. Bitte eine Zahl zwischen 1 und 65535 eingeben."
        fi
    done
    
    # Fotobox URL
    while true; do
        read -p "URL der Fotobox-Oberfläche (Standard: $DEFAULT_FOTOBOX_URL): " input_url
        if [ -z "$input_url" ]; then
            FOTOBOX_URL=$DEFAULT_FOTOBOX_URL
            break
        elif validate_url "$input_url"; then
            FOTOBOX_URL=$input_url
            break
        else
            print_error "Ungültige URL. Format: http://host:port oder https://host:port"
        fi
    done
    
    echo ""
    print_info "Konfiguration:"
    print_info "  WiFi-Config Port: $WIFI_CONFIG_PORT"
    print_info "  Fotobox URL: $FOTOBOX_URL"
    echo ""
    
    read -p "Sind diese Einstellungen korrekt? (j/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Jj]$ ]]; then
        configure_installation
    fi
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   print_error "This script must be run as root (use sudo)"
   exit 1
fi

print_status "Starting Raspberry Pi Fotobox WiFi Configuration installation..."

# Run interactive configuration
configure_installation

# Update system
print_status "Updating system packages..."
apt update
apt upgrade -y

# Fix any broken packages first
print_status "Fixing package dependencies..."
apt --fix-broken install -y
apt update

# Install dependencies
print_status "Installing required packages..."
apt install -y python3-pip python3-flask python3-venv

# Try to install Chromium, but don't fail if it's already installed
print_status "Installing Chromium browser..."
apt install -y chromium-browser chromium-codecs-ffmpeg || {
    print_warning "Chromium installation failed, trying alternative method..."
    # Try installing dependencies first
    apt install -y libraspberrypi0 || true
    apt install -y chromium-codecs-ffmpeg-extra || apt install -y chromium-codecs-ffmpeg || true
    apt install -y chromium-browser || {
        print_warning "Chromium might already be installed or needs manual installation"
        # Check if Chromium is already available
        if command -v chromium-browser &> /dev/null; then
            print_status "Chromium browser is already installed"
        else
            print_error "Please install Chromium browser manually"
        fi
    }
}

# Install Python packages
print_status "Installing Python dependencies..."
pip3 install flask flask-cors

# Create directory structure
print_status "Creating directory structure..."
mkdir -p /home/pi/wifi-config

# Update wifi_config_server.py with custom ports
print_status "Configuring WiFi server with custom settings..."
sed -i "s|FOTOBOX_URL = 'http://localhost:3353'|FOTOBOX_URL = '$FOTOBOX_URL'|g" wifi_config_server.py
sed -i "s|app.run(host='0.0.0.0', port=5000|app.run(host='0.0.0.0', port=$WIFI_CONFIG_PORT|g" wifi_config_server.py

# Update check_connection.sh with custom URL
sed -i "s|http://localhost:3353|$FOTOBOX_URL|g" check_connection.sh

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

# Update service file with custom port
print_status "Updating service configuration..."
sed -i "s|http://localhost:5000|http://localhost:$WIFI_CONFIG_PORT|g" wifi-config.service

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

# Create new autostart configuration with custom port
cat > "$AUTOSTART_FILE" << EOF
@lxpanel --profile LXDE-pi
@pcmanfm --desktop --profile LXDE-pi
@xscreensaver -no-splash

# Disable screen blanking
@xset s off
@xset -dpms
@xset s noblank

# Start WiFi configuration in kiosk mode
@chromium-browser --kiosk --noerrdialogs --disable-infobars --check-for-update-interval=604800 http://localhost:$WIFI_CONFIG_PORT

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
    ufw allow $WIFI_CONFIG_PORT/tcp comment 'WiFi Config'
    # Extract port from FOTOBOX_URL
    FOTOBOX_PORT=$(echo $FOTOBOX_URL | sed -e 's/.*://g' -e 's/\/.*//g')
    if validate_port "$FOTOBOX_PORT"; then
        ufw allow $FOTOBOX_PORT/tcp comment 'Fotobox'
    fi
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

# Create configuration summary file
print_status "Creating configuration summary..."
cat > /home/pi/wifi-config/config.txt << EOF
WiFi Configuration Settings
===========================
WiFi Config Port: $WIFI_CONFIG_PORT
WiFi Config URL: http://localhost:$WIFI_CONFIG_PORT
Fotobox URL: $FOTOBOX_URL

Service Commands:
- Status: sudo systemctl status wifi-config.service
- Restart: sudo systemctl restart wifi-config.service
- Logs: sudo journalctl -u wifi-config.service -f
EOF

chown pi:pi /home/pi/wifi-config/config.txt

# Check service status
print_status "Checking service status..."
if systemctl is-active --quiet wifi-config.service; then
    print_status "WiFi configuration service is running successfully!"
    echo ""
    print_info "=== Installation erfolgreich abgeschlossen! ==="
    print_info "WiFi-Konfiguration erreichbar unter: http://localhost:$WIFI_CONFIG_PORT"
    print_info "Fotobox wird weitergeleitet zu: $FOTOBOX_URL"
    print_info "Konfiguration gespeichert in: /home/pi/wifi-config/config.txt"
else
    print_error "Service failed to start. Check logs with: sudo journalctl -u wifi-config.service"
    exit 1
fi

echo ""
print_warning "Please reboot your Raspberry Pi to start using the WiFi configuration interface"
print_warning "Run: sudo reboot"

# Optional: Ask if user wants to reboot now
read -p "Do you want to reboot now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_status "Rebooting..."
    reboot
fi

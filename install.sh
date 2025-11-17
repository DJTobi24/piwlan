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

# Detect current user (fallback to pi if not exists)
if id "pi" &>/dev/null; then
    INSTALL_USER="pi"
    USER_HOME="/home/pi"
else
    # Use the user who called sudo, or current user if not using sudo
    if [ -n "$SUDO_USER" ]; then
        INSTALL_USER="$SUDO_USER"
    else
        INSTALL_USER="$(whoami)"
    fi
    USER_HOME=$(eval echo ~$INSTALL_USER)
fi

# Installation directories
INSTALL_DIR="$USER_HOME/wifi-config"
CONFIG_DIR="$USER_HOME/.config/lxsession/LXDE-pi"

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

# Function to check and install packages
install_required_packages() {
    print_status "Checking and installing required packages..."
    
    # List of required packages
    local packages=(
        "python3"
        "python3-pip"
        "python3-flask"
        "python3-venv"
        "git"
        "wget"
        "curl"
        "net-tools"
        "wireless-tools"
        "wpasupplicant"
        "dhcpcd5"
        "systemd"
        "lsof"
    )
    
    # Check which packages are missing
    local missing_packages=()
    for pkg in "${packages[@]}"; do
        if ! dpkg -l | grep -q "^ii  $pkg "; then
            missing_packages+=("$pkg")
        fi
    done
    
    # Install missing packages
    if [ ${#missing_packages[@]} -gt 0 ]; then
        print_status "Installing missing packages: ${missing_packages[*]}"
        apt update
        apt install -y "${missing_packages[@]}" || {
            print_warning "Some packages failed to install, continuing..."
        }
    else
        print_status "All required system packages are already installed"
    fi
    
    # Install Python packages
    print_status "Installing Python packages..."
    pip3 install --upgrade pip || print_warning "pip upgrade failed, continuing..."
    pip3 install flask flask-cors || {
        print_error "Failed to install Python packages"
        exit 1
    }
}

# Function to install browser
install_browser() {
    print_status "Checking for web browser..."
    
    # Check if any browser is installed
    if command -v chromium-browser &> /dev/null; then
        print_status "Chromium browser is already installed"
        BROWSER_COMMAND="chromium-browser"
    elif command -v chromium &> /dev/null; then
        print_status "Chromium is already installed"
        BROWSER_COMMAND="chromium"
    elif command -v firefox &> /dev/null; then
        print_status "Firefox is already installed"
        BROWSER_COMMAND="firefox"
    elif command -v firefox-esr &> /dev/null; then
        print_status "Firefox ESR is already installed"
        BROWSER_COMMAND="firefox-esr"
    else
        print_warning "No browser found, attempting to install..."
        
        # Try to install Chromium first
        apt install -y chromium-browser chromium-codecs-ffmpeg 2>/dev/null || \
        apt install -y chromium 2>/dev/null || \
        apt install -y firefox-esr 2>/dev/null || {
            print_error "Failed to install any browser automatically"
            print_warning "Please install a browser manually (chromium or firefox)"
            BROWSER_COMMAND="chromium-browser"  # Default fallback
        }
        
        # Check again which browser was installed
        if command -v chromium-browser &> /dev/null; then
            BROWSER_COMMAND="chromium-browser"
        elif command -v chromium &> /dev/null; then
            BROWSER_COMMAND="chromium"
        elif command -v firefox-esr &> /dev/null; then
            BROWSER_COMMAND="firefox-esr"
        else
            BROWSER_COMMAND="chromium-browser"  # Default fallback
        fi
    fi
    
    print_info "Browser command: $BROWSER_COMMAND"
}

# Check if already installed
check_existing_installation() {
    if [ -d "$INSTALL_DIR" ] && [ -f "$INSTALL_DIR/config.txt" ]; then
        return 0  # Installation exists
    else
        return 1  # No installation found
    fi
}

# Load existing configuration
load_existing_config() {
    if [ -f "$INSTALL_DIR/config.txt" ]; then
        # Extract port from config.txt
        WIFI_CONFIG_PORT=$(grep "WiFi Config Port:" "$INSTALL_DIR/config.txt" | awk '{print $4}')
        FOTOBOX_URL=$(grep "Fotobox URL:" "$INSTALL_DIR/config.txt" | awk '{print $3}')

        # Fallback to defaults if extraction failed
        [ -z "$WIFI_CONFIG_PORT" ] && WIFI_CONFIG_PORT=$DEFAULT_WIFI_CONFIG_PORT
        [ -z "$FOTOBOX_URL" ] && FOTOBOX_URL=$DEFAULT_FOTOBOX_URL

        print_info "Existierende Konfiguration gefunden:"
        print_info "  WiFi-Config Port: $WIFI_CONFIG_PORT"
        print_info "  Fotobox URL: $FOTOBOX_URL"
    fi
}

# Update existing installation
update_installation() {
    print_status "Aktualisiere existierende Installation..."

    # Stop service first
    print_status "Stoppe WiFi-Config Service..."
    systemctl stop wifi-config.service 2>/dev/null || true

    # Backup old files
    BACKUP_DIR="$INSTALL_DIR/backup-$(date +%Y%m%d-%H%M%S)"
    print_status "Erstelle Backup in $BACKUP_DIR..."
    mkdir -p "$BACKUP_DIR"
    cp "$INSTALL_DIR/index.html" "$BACKUP_DIR/" 2>/dev/null || true
    cp "$INSTALL_DIR/wifi_config_server.py" "$BACKUP_DIR/" 2>/dev/null || true
    cp "$INSTALL_DIR/check_connection.sh" "$BACKUP_DIR/" 2>/dev/null || true

    # Update files
    print_status "Aktualisiere Dateien..."
    return 0
}

# Interactive configuration
configure_installation() {
    echo ""
    print_info "=== Konfiguration der Installation ==="
    print_info "Installationsbenutzer: $INSTALL_USER"
    print_info "Home-Verzeichnis: $USER_HOME"
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

# Check if already installed
if check_existing_installation; then
    echo ""
    print_warning "Eine existierende Installation wurde gefunden in: $INSTALL_DIR"
    load_existing_config
    echo ""
    read -p "Möchten Sie die Installation aktualisieren? (j/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Jj]$ ]]; then
        UPDATE_MODE=true
        print_info "Update-Modus aktiviert - verwende existierende Konfiguration"
        echo ""
        read -p "Möchten Sie die Konfiguration ändern? (j/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Jj]$ ]]; then
            configure_installation
        fi
    else
        print_error "Installation abgebrochen."
        exit 0
    fi
else
    UPDATE_MODE=false
    # Run interactive configuration
    configure_installation
fi

# Update mode: Stop service and create backup
if [ "$UPDATE_MODE" = true ]; then
    update_installation
else
    # Update system
    print_status "Updating system packages..."
    apt update || {
        print_warning "apt update failed, trying to continue..."
    }

    # Fix any broken packages first
    print_status "Fixing package dependencies..."
    apt --fix-broken install -y || true
    dpkg --configure -a || true

    # Install required packages
    install_required_packages

    # Install browser
    install_browser
fi

# Create directory structure
print_status "Creating directory structure..."
mkdir -p "$INSTALL_DIR"
mkdir -p "$CONFIG_DIR"

# Check if files exist in current directory
if [ ! -f "index.html" ] || [ ! -f "wifi_config_server.py" ]; then
    print_error "Required files not found in current directory!"
    print_error "Please run this script from the piwlan directory"
    exit 1
fi

# Update wifi_config_server.py with custom ports
print_status "Configuring WiFi server with custom settings..."
cp wifi_config_server.py wifi_config_server.py.tmp
sed -i "s|FOTOBOX_URL = 'http://localhost:3353'|FOTOBOX_URL = '$FOTOBOX_URL'|g" wifi_config_server.py.tmp
sed -i "s|port=5000|port=$WIFI_CONFIG_PORT|g" wifi_config_server.py.tmp
sed -i "s|int(os.environ.get('WIFI_CONFIG_PORT', 5000))|int(os.environ.get('WIFI_CONFIG_PORT', $WIFI_CONFIG_PORT))|g" wifi_config_server.py.tmp

# Update check_connection.sh with custom URL
if [ -f "check_connection.sh" ]; then
    cp check_connection.sh check_connection.sh.tmp
    sed -i "s|http://localhost:3353|$FOTOBOX_URL|g" check_connection.sh.tmp
else
    print_warning "check_connection.sh not found, creating default version..."
    cat > check_connection.sh.tmp << EOF
#!/bin/bash
# WiFi Connection Check Script
FOTOBOX_URL="$FOTOBOX_URL"
sleep 10
if ping -c 1 -W 2 8.8.8.8 > /dev/null 2>&1; then
    echo "Internet connection available - redirecting to photo booth"
    sleep 5
    pkill -f chromium
    export DISPLAY=:0
    $BROWSER_COMMAND --kiosk --noerrdialogs --disable-infobars \$FOTOBOX_URL &
else
    echo "No internet connection - staying on WiFi configuration"
fi
echo "\$(date): Connection check completed" >> /var/log/wifi-config-check.log
EOF
fi

# Copy files
print_status "Copying configuration files..."
cp index.html "$INSTALL_DIR/"
cp wifi_config_server.py.tmp "$INSTALL_DIR/wifi_config_server.py"
cp check_connection.sh.tmp "$INSTALL_DIR/check_connection.sh"

# Copy debug script if exists
if [ -f "debug_wifi_config.sh" ]; then
    cp debug_wifi_config.sh "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/debug_wifi_config.sh"
fi

# Clean up temp files
rm -f wifi_config_server.py.tmp check_connection.sh.tmp

# Set permissions
print_status "Setting file permissions..."
chmod +x "$INSTALL_DIR/wifi_config_server.py"
chmod +x "$INSTALL_DIR/check_connection.sh"
chown -R $INSTALL_USER:$INSTALL_USER "$INSTALL_DIR"

# Update service file with custom paths and port
print_status "Creating systemd service..."
cat > wifi-config.service.tmp << EOF
[Unit]
Description=WiFi Configuration Web Interface for Raspberry Pi Fotobox
After=network.target
Wants=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/bin/python3 $INSTALL_DIR/wifi_config_server.py
Restart=always
RestartSec=10
StandardOutput=append:/var/log/wifi-config.log
StandardError=append:/var/log/wifi-config.log
Environment="WIFI_CONFIG_PORT=$WIFI_CONFIG_PORT"

# Security settings
PrivateTmp=true
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=read-only
ReadWritePaths=/etc/wpa_supplicant /var/log

[Install]
WantedBy=multi-user.target
EOF

# Install service
cp wifi-config.service.tmp /etc/systemd/system/wifi-config.service
rm wifi-config.service.tmp

# Create log file
touch /var/log/wifi-config.log
chown $INSTALL_USER:$INSTALL_USER /var/log/wifi-config.log

# Configure autostart for kiosk mode
print_status "Configuring kiosk mode..."
AUTOSTART_FILE="$CONFIG_DIR/autostart"

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
@$BROWSER_COMMAND --kiosk --noerrdialogs --disable-infobars http://localhost:$WIFI_CONFIG_PORT

# Check connection after startup
@$INSTALL_DIR/check_connection.sh
EOF

chown $INSTALL_USER:$INSTALL_USER "$AUTOSTART_FILE"

# Enable and start service
print_status "Enabling and starting WiFi configuration service..."
systemctl daemon-reload
systemctl enable wifi-config.service
systemctl start wifi-config.service

# Configure firewall (if ufw is installed)
if command -v ufw &> /dev/null; then
    print_status "Configuring firewall..."
    ufw allow $WIFI_CONFIG_PORT/tcp comment 'WiFi Config' || true
    # Extract port from FOTOBOX_URL
    FOTOBOX_PORT=$(echo $FOTOBOX_URL | sed -e 's/.*://g' -e 's/\/.*//g')
    if validate_port "$FOTOBOX_PORT"; then
        ufw allow $FOTOBOX_PORT/tcp comment 'Fotobox' || true
    fi
    ufw --force enable || true
fi

# Create log rotation config
print_status "Setting up log rotation..."
cat > /etc/logrotate.d/wifi-config << EOF
/var/log/wifi-config.log
/var/log/wifi-config-check.log
{
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 $INSTALL_USER $INSTALL_USER
}
EOF

# Create configuration summary file
print_status "Creating configuration summary..."
cat > "$INSTALL_DIR/config.txt" << EOF
WiFi Configuration Settings
===========================
Installation User: $INSTALL_USER
Installation Directory: $INSTALL_DIR
WiFi Config Port: $WIFI_CONFIG_PORT
WiFi Config URL: http://localhost:$WIFI_CONFIG_PORT
Fotobox URL: $FOTOBOX_URL
Browser Command: $BROWSER_COMMAND

Service Commands:
- Status: sudo systemctl status wifi-config.service
- Restart: sudo systemctl restart wifi-config.service
- Logs: sudo journalctl -u wifi-config.service -f
- Debug: sudo $INSTALL_DIR/debug_wifi_config.sh

File Locations:
- HTML Interface: $INSTALL_DIR/index.html
- Python Server: $INSTALL_DIR/wifi_config_server.py
- Service File: /etc/systemd/system/wifi-config.service
- Autostart: $AUTOSTART_FILE
EOF

chown $INSTALL_USER:$INSTALL_USER "$INSTALL_DIR/config.txt"

# Check service status
print_status "Checking service status..."
sleep 2
if systemctl is-active --quiet wifi-config.service; then
    print_status "WiFi configuration service is running successfully!"
    echo ""
    if [ "$UPDATE_MODE" = true ]; then
        print_info "=== Update erfolgreich abgeschlossen! ==="
        print_info "Die Installation wurde aktualisiert."
        if [ -n "$BACKUP_DIR" ] && [ -d "$BACKUP_DIR" ]; then
            print_info "Backup der alten Dateien: $BACKUP_DIR"
        fi
    else
        print_info "=== Installation erfolgreich abgeschlossen! ==="
    fi
    print_info "Benutzer: $INSTALL_USER"
    print_info "Installationsverzeichnis: $INSTALL_DIR"
    print_info "WiFi-Konfiguration erreichbar unter: http://localhost:$WIFI_CONFIG_PORT"
    print_info "Fotobox wird weitergeleitet zu: $FOTOBOX_URL"
    print_info "Konfiguration gespeichert in: $INSTALL_DIR/config.txt"
else
    print_error "Service failed to start. Check logs with: sudo journalctl -u wifi-config.service"
    print_info "You can also run the debug script: sudo $INSTALL_DIR/debug_wifi_config.sh"
fi

echo ""
if [ "$UPDATE_MODE" = true ]; then
    print_info "Hinweis: Das Update wurde abgeschlossen. Der Service wurde neu gestartet."
    print_info "Sie können die Änderungen sofort nutzen (kein Neustart erforderlich)."
    echo ""
    read -p "Möchten Sie trotzdem neu starten? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Rebooting..."
        reboot
    fi
else
    print_warning "Please reboot your Raspberry Pi to start using the WiFi configuration interface"
    print_warning "Run: sudo reboot"

    # Optional: Ask if user wants to reboot now
    read -p "Do you want to reboot now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Rebooting..."
        reboot
    fi
fi

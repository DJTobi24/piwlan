#!/bin/bash

# WiFi Config Toggle Script - Enable/Disable WiFi configuration at startup

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${GREEN}[+]${NC} $1"; }
print_error() { echo -e "${RED}[!]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[*]${NC} $1"; }
print_info() { echo -e "${BLUE}[i]${NC} $1"; }

# Detect user and paths
if id "pi" &>/dev/null; then
    INSTALL_USER="pi"
    USER_HOME="/home/pi"
else
    if [ -n "$SUDO_USER" ]; then
        INSTALL_USER="$SUDO_USER"
    else
        INSTALL_USER="$(whoami)"
    fi
    USER_HOME=$(eval echo ~$INSTALL_USER)
fi

AUTOSTART_FILE="$USER_HOME/.config/lxsession/LXDE-pi/autostart"
INSTALL_DIR="$USER_HOME/wifi-config"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   print_error "This script must be run as root (use sudo)"
   exit 1
fi

# Function to disable WiFi config at startup
disable_wifi_config() {
    print_status "Disabling WiFi configuration at startup..."
    
    # Comment out WiFi config lines in autostart
    if [ -f "$AUTOSTART_FILE" ]; then
        cp "$AUTOSTART_FILE" "${AUTOSTART_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        
        # Comment out the browser line that opens WiFi config
        sed -i 's|^@.*--kiosk.*localhost.*|#&|' "$AUTOSTART_FILE"
        
        # Comment out the connection check
        sed -i 's|^@.*/check_connection.sh|#&|' "$AUTOSTART_FILE"
        
        print_status "WiFi configuration disabled in autostart"
    fi
    
    # Stop the service
    systemctl stop wifi-config.service 2>/dev/null || true
    systemctl disable wifi-config.service 2>/dev/null || true
    
    print_status "WiFi configuration service disabled"
    print_info "The WiFi configuration page will NOT load at startup"
    print_info "You can still access it manually at http://localhost:5000"
}

# Function to enable WiFi config at startup
enable_wifi_config() {
    print_status "Enabling WiFi configuration at startup..."
    
    # Read config to get the port
    WIFI_CONFIG_PORT=5000
    if [ -f "$INSTALL_DIR/config.txt" ]; then
        PORT=$(grep "WiFi Config Port:" "$INSTALL_DIR/config.txt" | cut -d: -f2 | tr -d ' ')
        [ -n "$PORT" ] && WIFI_CONFIG_PORT=$PORT
    fi
    
    # Detect browser
    if command -v chromium-browser &> /dev/null; then
        BROWSER_CMD="chromium-browser"
    elif command -v chromium &> /dev/null; then
        BROWSER_CMD="chromium"
    elif command -v firefox-esr &> /dev/null; then
        BROWSER_CMD="firefox-esr"
    else
        BROWSER_CMD="chromium-browser"
    fi
    
    # Restore or create autostart
    if [ -f "$AUTOSTART_FILE" ]; then
        # First uncomment any commented lines
        sed -i 's|^#\(@.*--kiosk.*localhost.*\)|\1|' "$AUTOSTART_FILE"
        sed -i 's|^#\(@.*/check_connection.sh\)|\1|' "$AUTOSTART_FILE"
        
        # Check if lines exist
        if ! grep -q "@.*--kiosk.*localhost" "$AUTOSTART_FILE"; then
            # Add the lines if they don't exist
            cat >> "$AUTOSTART_FILE" << EOF

# Start WiFi configuration in kiosk mode
@$BROWSER_CMD --kiosk --noerrdialogs --disable-infobars http://localhost:$WIFI_CONFIG_PORT

# Check connection after startup
@$INSTALL_DIR/check_connection.sh
EOF
        fi
    else
        # Create new autostart file
        mkdir -p "$(dirname "$AUTOSTART_FILE")"
        cat > "$AUTOSTART_FILE" << EOF
@lxpanel --profile LXDE-pi
@pcmanfm --desktop --profile LXDE-pi
@xscreensaver -no-splash

# Disable screen blanking
@xset s off
@xset -dpms
@xset s noblank

# Start WiFi configuration in kiosk mode
@$BROWSER_CMD --kiosk --noerrdialogs --disable-infobars http://localhost:$WIFI_CONFIG_PORT

# Check connection after startup
@$INSTALL_DIR/check_connection.sh
EOF
    fi
    
    chown $INSTALL_USER:$INSTALL_USER "$AUTOSTART_FILE"
    
    # Enable the service
    systemctl enable wifi-config.service 2>/dev/null || true
    systemctl start wifi-config.service 2>/dev/null || true
    
    print_status "WiFi configuration enabled in autostart"
    print_info "The WiFi configuration page WILL load at startup"
}

# Function to show current status
show_status() {
    echo ""
    print_info "=== Current WiFi Configuration Status ==="
    
    # Check autostart
    if [ -f "$AUTOSTART_FILE" ]; then
        if grep -q "^@.*--kiosk.*localhost" "$AUTOSTART_FILE"; then
            print_status "Autostart: ENABLED"
        else
            print_warning "Autostart: DISABLED"
        fi
    else
        print_error "Autostart file not found"
    fi
    
    # Check service
    if systemctl is-enabled wifi-config.service &>/dev/null; then
        print_status "Service: ENABLED"
    else
        print_warning "Service: DISABLED"
    fi
    
    if systemctl is-active wifi-config.service &>/dev/null; then
        print_status "Service Status: RUNNING"
    else
        print_warning "Service Status: STOPPED"
    fi
    
    echo ""
}

# Main menu
echo ""
echo "=== WiFi Configuration Startup Toggle ==="
echo ""

show_status

echo "What would you like to do?"
echo "1) Disable WiFi config at startup (boot directly to desktop)"
echo "2) Enable WiFi config at startup (show WiFi config page)"
echo "3) Exit"
echo ""

read -p "Select option (1-3): " choice

case $choice in
    1)
        disable_wifi_config
        echo ""
        print_info "Please reboot for changes to take effect"
        ;;
    2)
        enable_wifi_config
        echo ""
        print_info "Please reboot for changes to take effect"
        ;;
    3)
        echo "Exiting..."
        exit 0
        ;;
    *)
        print_error "Invalid choice"
        exit 1
        ;;
esac

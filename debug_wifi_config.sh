#!/bin/bash

# Debug and repair script for WiFi Configuration Service

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${GREEN}[+]${NC} $1"; }
print_error() { echo -e "${RED}[!]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[*]${NC} $1"; }
print_info() { echo -e "${BLUE}[i]${NC} $1"; }

echo "=== WiFi Configuration Service Debug Tool ==="
echo ""

# Check current service status
print_info "Service Status:"
systemctl status wifi-config.service --no-pager | grep -E "Active:|Main PID:"

# Check what's using port 5000
print_info "\nChecking port 5000:"
if lsof -i :5000 >/dev/null 2>&1; then
    print_warning "Port 5000 is in use by:"
    sudo lsof -i :5000
else
    print_status "Port 5000 is free"
fi

# Find all wifi_config_server processes
print_info "\nChecking for running processes:"
if pgrep -f wifi_config_server.py > /dev/null; then
    print_warning "Found wifi_config_server.py processes:"
    ps aux | grep -E "wifi_config_server.py|PID" | grep -v grep
else
    print_status "No wifi_config_server.py processes found"
fi

# Show recent logs
print_info "\nRecent error logs:"
tail -n 20 /var/log/wifi-config.log | grep -E "ERROR|Error|OSError" | tail -5

echo ""
echo "=== Available Actions ==="
echo "1) Stop service and kill all processes"
echo "2) Change to different port (8080)"
echo "3) Restart service with current settings"
echo "4) Show full logs"
echo "5) Test if server can start manually"
echo "6) Exit"
echo ""

read -p "Select action (1-6): " choice

case $choice in
    1)
        print_status "Stopping service and killing processes..."
        sudo systemctl stop wifi-config.service
        sudo pkill -f wifi_config_server.py
        sleep 2
        print_status "Done. Service stopped and processes killed."
        ;;
    2)
        print_status "Changing to port 8080..."
        sudo systemctl stop wifi-config.service
        sudo pkill -f wifi_config_server.py
        
        # Update the Python file
        sudo sed -i 's/port=5000/port=8080/g' /home/pi/wifi-config/wifi_config_server.py
        sudo sed -i "s/int(os.environ.get('WIFI_CONFIG_PORT', 5000))/int(os.environ.get('WIFI_CONFIG_PORT', 8080))/g" /home/pi/wifi-config/wifi_config_server.py
        
        # Update autostart
        sudo sed -i 's/:5000/:8080/g' /home/pi/.config/lxsession/LXDE-pi/autostart
        
        # Update systemd service
        sudo systemctl daemon-reload
        sudo systemctl start wifi-config.service
        
        print_status "Changed to port 8080. Service restarted."
        print_info "Access at: http://localhost:8080"
        ;;
    3)
        print_status "Restarting service..."
        sudo systemctl stop wifi-config.service
        sudo pkill -f wifi_config_server.py
        sleep 2
        sudo systemctl start wifi-config.service
        sleep 2
        systemctl status wifi-config.service --no-pager | grep -E "Active:"
        ;;
    4)
        print_info "Showing last 50 lines of logs:"
        echo "--- System logs ---"
        sudo journalctl -u wifi-config.service -n 50 --no-pager
        echo ""
        echo "--- Application logs ---"
        tail -n 50 /var/log/wifi-config.log
        ;;
    5)
        print_status "Testing manual start (Ctrl+C to stop)..."
        sudo systemctl stop wifi-config.service
        sudo pkill -f wifi_config_server.py
        sleep 2
        cd /home/pi/wifi-config
        sudo WIFI_CONFIG_PORT=8888 python3 wifi_config_server.py
        ;;
    6)
        echo "Exiting..."
        exit 0
        ;;
    *)
        print_error "Invalid choice"
        ;;
esac

echo ""
print_info "Run this script again for more options."

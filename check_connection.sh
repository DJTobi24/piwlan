#!/bin/bash

# WiFi Connection Check Script
# Automatically redirects to photo booth if internet is available

# Default URL - will be replaced by install script
FOTOBOX_URL="http://localhost:3353"

# Wait for system to fully start
sleep 10

# Check if we already have internet connection
if ping -c 1 -W 2 8.8.8.8 > /dev/null 2>&1; then
    echo "Internet connection available - redirecting to photo booth"
    
    # Wait a bit more to ensure everything is loaded
    sleep 5
    
    # Kill any existing chromium instances
    pkill -f chromium
    
    # Start chromium with photo booth URL
    export DISPLAY=:0
    chromium-browser --kiosk --noerrdialogs --disable-infobars --check-for-update-interval=604800 $FOTOBOX_URL &
else
    echo "No internet connection - staying on WiFi configuration"
    # The WiFi configuration page is already loaded by autostart
fi

# Log the status
echo "$(date): Connection check completed - Internet: $(ping -c 1 -W 2 8.8.8.8 > /dev/null 2>&1 && echo 'YES' || echo 'NO')" >> /var/log/wifi-config-check.log

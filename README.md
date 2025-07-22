# Raspberry Pi Fotobox WiFi Configuration

A modern, touch-friendly WiFi configuration interface for Raspberry Pi-based photo booths. This solution allows users to easily connect to WiFi networks without needing SSH access or a keyboard.

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Python](https://img.shields.io/badge/python-3.7+-blue.svg)
![Raspberry Pi](https://img.shields.io/badge/Raspberry%20Pi-5-red.svg)

## 🌟 Features

- **Touch-Optimized Interface**: Large buttons and inputs designed for touchscreen use
- **Modern UI Design**: Glassmorphism effects with smooth animations
- **Auto-Discovery**: Automatically scans and displays available WiFi networks
- **Connection Status**: Shows current WiFi connection with direct access to photo booth
- **Secure Connection**: Supports WPA/WPA2 encrypted networks
- **Automatic Redirect**: Redirects to photo booth application after successful connection
- **No Keyboard Required**: Complete configuration through touch interface only
- **Kiosk Mode Ready**: Designed to run in fullscreen kiosk mode
- **Configurable Ports**: Customize WiFi config and photo booth ports during installation

## 📸 Screenshots

### Connected State
When already connected to WiFi, users see:
- ✅ Connection status
- Direct button to photo booth
- Option to change WiFi network

### Network Selection
When not connected or changing networks:
- List of available networks
- Signal strength indicators
- Password input with visibility toggle

## 📋 Prerequisites

- Raspberry Pi 5 (or compatible model)
- Raspberry Pi OS (Bullseye or newer)
- Python 3.7+
- Touchscreen display
- Working photo booth application

## 🚀 Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/DJTobi24/piwlan.git
cd piwlan
```

### 2. Run Installation Script

```bash
chmod +x install.sh
sudo ./install.sh
```

During installation, you'll be asked to configure:
- WiFi configuration port (default: 5000)
- Photo booth URL (default: http://localhost:3353)

### 3. Reboot

```bash
sudo reboot
```

## 📦 Manual Installation

If you prefer manual installation or need to customize the setup:

### Step 1: Install Dependencies

```bash
sudo apt update
sudo apt install -y python3-pip python3-flask
sudo pip3 install flask flask-cors
```

### Step 2: Copy Files

```bash
sudo mkdir -p /home/pi/wifi-config
sudo cp index.html /home/pi/wifi-config/
sudo cp wifi_config_server.py /home/pi/wifi-config/
sudo chmod +x /home/pi/wifi-config/wifi_config_server.py
```

### Step 3: Install Service

```bash
sudo cp wifi-config.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable wifi-config.service
sudo systemctl start wifi-config.service
```

### Step 4: Configure Kiosk Mode

Add to `/home/pi/.config/lxsession/LXDE-pi/autostart`:

```bash
@xset s off
@xset -dpms
@xset s noblank
@chromium-browser --kiosk --noerrdialogs --disable-infobars http://localhost:5000
```

## 🎯 Usage

1. **Power on** the Raspberry Pi with the touchscreen attached
2. **Connected State**: If already connected to WiFi, you'll see:
   - Current WiFi network name
   - Green "Go to Photo Booth" button
   - Option to change WiFi network
3. **Not Connected**: If not connected, you'll see:
   - List of available WiFi networks
   - Tap to select a network
   - Enter password (if required)
   - Automatic redirect to photo booth upon connection

## 🔧 Configuration

### Change Ports After Installation

**WiFi Config Port:**
```bash
sudo nano /home/pi/wifi-config/wifi_config_server.py
# Change: app.run(host='0.0.0.0', port=5000)
```

**Photo Booth URL:**
```bash
sudo nano /home/pi/wifi-config/wifi_config_server.py
# Change: FOTOBOX_URL = 'http://localhost:3353'

sudo nano /home/pi/wifi-config/check_connection.sh
# Change: FOTOBOX_URL="http://localhost:3353"
```

After changes:
```bash
sudo systemctl restart wifi-config.service
```

### Customize UI Theme

Edit the CSS in `index.html`:

```css
/* Change gradient colors */
background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);

/* Change accent color */
border-color: #667eea;

/* Change success color */
background: #27ae60;
```

## 🐛 Troubleshooting

### Port Already in Use

```bash
# Check what's using the port
sudo lsof -i :5000

# Stop the service and kill processes
sudo systemctl stop wifi-config.service
sudo pkill -f wifi_config_server.py

# Change to different port (e.g., 8080)
sudo ./debug_wifi_config.sh
```

### No Networks Displayed

```bash
# Check WiFi interface
sudo iwconfig

# Check service logs
sudo journalctl -u wifi-config.service -f

# Check application logs
sudo tail -f /var/log/wifi-config.log
```

### Connection Fails

```bash
# Check WPA supplicant
sudo journalctl -u wpa_supplicant -f

# Test manual scan
sudo iwlist wlan0 scan
```

### Service Not Starting

```bash
# Check service status
sudo systemctl status wifi-config.service

# Run debug script
sudo ./debug_wifi_config.sh
```

## 📁 File Structure

```
piwlan/
├── README.md              # This file
├── LICENSE               # MIT License
├── install.sh            # Automated installation script
├── index.html            # WiFi configuration interface
├── wifi_config_server.py # Backend server
├── wifi-config.service   # Systemd service file
├── check_connection.sh   # Connection check script
├── debug_wifi_config.sh  # Debug and repair tool
└── .gitignore           # Git ignore file
```

## 🛠️ Debug Tool

The project includes a debug tool for troubleshooting:

```bash
sudo ./debug_wifi_config.sh
```

Options:
1. Stop service and kill all processes
2. Change to different port
3. Restart service
4. Show logs
5. Test manual start

## 🔒 Security Considerations

- WiFi passwords are stored in `/etc/wpa_supplicant/wpa_supplicant.conf`
- Service runs with root privileges (required for network configuration)
- Web interface is only accessible locally by default
- Consider implementing authentication for production use

## 📝 API Endpoints

The backend provides these endpoints:

- `GET /` - Serves the web interface
- `GET /api/networks` - Returns available WiFi networks
- `POST /api/connect` - Connect to a network
- `GET /api/status` - Get connection status
- `GET /api/redirect` - Redirect to photo booth

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Designed specifically for touchscreen photo booth applications
- UI inspired by modern glassmorphism design trends
- Built with Flask for simplicity and reliability
- Special thanks to the Raspberry Pi photo booth community

## 💬 Support

For issues and questions:
- Open an issue on [GitHub](https://github.com/DJTobi24/piwlan/issues)
- Check existing issues for solutions
- Review the troubleshooting section

## 🚀 Future Plans

- [ ] Multiple WiFi profile support
- [ ] WiFi strength monitoring
- [ ] Captive portal support
- [ ] Multi-language support
- [ ] Advanced network diagnostics
- [ ] REST API authentication

---

Made with ❤️ for the Raspberry Pi photo booth community

**Project Link**: [https://github.com/DJTobi24/piwlan](https://github.com/DJTobi24/piwlan)

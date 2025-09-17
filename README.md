# Raspberry Pi Fotobox WiFi Configuration

A modern, touch-friendly WiFi configuration interface for Raspberry Pi-based photo booths. This solution allows users to easily connect to WiFi networks without needing SSH access or a keyboard.

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Python](https://img.shields.io/badge/python-3.7+-blue.svg)
![Raspberry Pi](https://img.shields.io/badge/Raspberry%20Pi-Compatible-red.svg)

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
- **Multi-User Support**: Automatically detects and uses appropriate user (not limited to 'pi')
- **Toggle Startup**: Enable/disable WiFi configuration at startup with simple commands

## 📸 Screenshots

### Connected State
When already connected to WiFi, users see:
- ✅ Connection status with network name
- Direct green button to photo booth
- Option to change WiFi network

### Network Selection
When not connected or changing networks:
- List of available networks with signal strength
- Currently connected network highlighted
- Password input with visibility toggle
- Touch-friendly interface

## 📋 Prerequisites

- Raspberry Pi (any model with WiFi)
- Raspberry Pi OS (Bullseye or newer)
- Python 3.7+
- Touchscreen display (optional but recommended)
- Active photo booth application

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

The installer will:
- ✅ Detect your username automatically (works with any user, not just 'pi')
- ✅ Install ALL required packages automatically
- ✅ Find or install a compatible browser
- ✅ Configure custom ports for WiFi config and photo booth

During installation, you'll be asked:
- WiFi configuration port (default: 5000)
- Photo booth URL (default: http://localhost:3353)

### 3. Reboot

```bash
sudo reboot
```

## 🎯 Usage

### Normal Operation

1. **Power on** the Raspberry Pi
2. **Connected State**: If already connected to WiFi:
   - Shows current network name
   - Green "Zur Fotobox →" button for direct access
   - "Anderes WLAN wählen" to change networks
3. **Not Connected**: If no WiFi connection:
   - Shows available networks list
   - Tap to select network
   - Enter password if required
   - Auto-redirect to photo booth after connection

### Enable/Disable at Startup

You can control whether the WiFi configuration loads at startup:

**Quick Commands:**
```bash
# Disable WiFi config at startup (boot directly to desktop)
sudo wifi-config-toggle

# Or use one-line commands:
# Disable
sudo systemctl disable wifi-config.service && sudo sed -i 's|^@.*--kiosk.*localhost.*|#&|' ~/.config/lxsession/LXDE-pi/autostart

# Enable
sudo systemctl enable wifi-config.service && sudo sed -i 's|^#\(@.*--kiosk.*localhost.*\)|\1|' ~/.config/lxsession/LXDE-pi/autostart
```

## 📦 Manual Installation

<details>
<summary>Click to expand manual installation steps</summary>

### Step 1: Install Dependencies

```bash
sudo apt update
sudo apt install -y python3 python3-pip git wget curl net-tools wireless-tools wpasupplicant dhcpcd5
sudo pip3 install flask flask-cors
```

### Step 2: Copy Files

```bash
# Detect user
INSTALL_USER=${SUDO_USER:-$(whoami)}
USER_HOME=$(eval echo ~$INSTALL_USER)

# Create directories
sudo mkdir -p $USER_HOME/wifi-config
sudo cp index.html $USER_HOME/wifi-config/
sudo cp wifi_config_server.py $USER_HOME/wifi-config/
sudo chmod +x $USER_HOME/wifi-config/wifi_config_server.py
```

### Step 3: Install Service

```bash
sudo cp wifi-config.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable wifi-config.service
sudo systemctl start wifi-config.service
```

### Step 4: Configure Kiosk Mode

Add to `~/.config/lxsession/LXDE-pi/autostart`:

```bash
@xset s off
@xset -dpms
@xset s noblank
@chromium-browser --kiosk --noerrdialogs --disable-infobars http://localhost:5000
```

</details>

## 🔧 Configuration

### Change Settings After Installation

The installation creates a configuration file at `~/wifi-config/config.txt` with all your settings.

**Change WiFi Config Port:**
```bash
sudo nano ~/wifi-config/wifi_config_server.py
# Change: app.run(host='0.0.0.0', port=5000)
sudo systemctl restart wifi-config.service
```

**Change Photo Booth URL:**
```bash
sudo nano ~/wifi-config/wifi_config_server.py
# Change: FOTOBOX_URL = 'http://localhost:3353'

sudo nano ~/wifi-config/check_connection.sh
# Change: FOTOBOX_URL="http://localhost:3353"

sudo systemctl restart wifi-config.service
```

### Startup Configuration

**Install Toggle Script:**
```bash
sudo cp wifi-config-toggle.sh /usr/local/bin/wifi-config-toggle
sudo chmod +x /usr/local/bin/wifi-config-toggle
```

**Use Toggle Script:**
```bash
sudo wifi-config-toggle
# Shows menu to enable/disable WiFi config at startup
```

### Customize UI Theme

Edit the CSS in `index.html`:

```css
/* Change gradient colors */
background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);

/* Change success color */
background: #27ae60;

/* Change button styles */
border-radius: 10px;
```

## 🐛 Troubleshooting

### Debug Tool

The project includes a comprehensive debug tool:

```bash
sudo ~/wifi-config/debug_wifi_config.sh
```

Options:
1. Stop service and kill all processes
2. Change to different port (8080)
3. Restart service
4. Show full logs
5. Test manual start

### Common Issues

**Port Already in Use:**
```bash
# Check what's using the port
sudo lsof -i :5000

# Use debug tool to change port
sudo ~/wifi-config/debug_wifi_config.sh
# Select option 2
```

**No Networks Displayed:**
```bash
# Check WiFi interface
sudo iwconfig

# Test manual scan
sudo iwlist wlan0 scan

# Check logs
sudo journalctl -u wifi-config.service -f
```

**Browser Not Found:**
```bash
# Install Chromium
sudo apt install -y chromium-browser

# Or Firefox ESR
sudo apt install -y firefox-esr
```

**Service Not Starting:**
```bash
# Check service status
sudo systemctl status wifi-config.service

# View detailed logs
sudo tail -f /var/log/wifi-config.log

# Try manual start
cd ~/wifi-config
sudo python3 wifi_config_server.py
```

## 📁 File Structure

```
piwlan/
├── README.md              # This file
├── LICENSE               # MIT License
├── install.sh            # Smart installation script
├── index.html            # Touch-optimized web interface
├── wifi_config_server.py # Backend server with API
├── wifi-config.service   # Systemd service file
├── check_connection.sh   # Auto-redirect script
├── debug_wifi_config.sh  # Debug and troubleshooting tool
├── wifi-config-toggle.sh # Enable/disable startup tool
└── .gitignore           # Git ignore file
```

## 🔒 Security Considerations

- WiFi passwords are stored in `/etc/wpa_supplicant/wpa_supplicant.conf`
- Service runs with root privileges (required for network configuration)
- Web interface is localhost-only by default
- Consider adding authentication for production deployments
- Regular security updates recommended

## 📝 API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | Serves the web interface |
| `/api/networks` | GET | Returns available WiFi networks |
| `/api/connect` | POST | Connect to a network |
| `/api/status` | GET | Get current connection status |
| `/api/redirect` | GET | Redirect to photo booth URL |

## 🛠️ Advanced Features

### Multi-User Support

The installation automatically detects and uses the appropriate user:
- Works with default 'pi' user
- Automatically uses current user if 'pi' doesn't exist
- All paths adjusted dynamically

### Browser Compatibility

Supports multiple browsers (auto-detected):
- Chromium Browser (preferred)
- Chromium
- Firefox ESR
- Firefox

### Package Management

The installer automatically installs all required packages:
- Python packages: flask, flask-cors
- Network tools: wpasupplicant, wireless-tools, dhcpcd5
- System tools: git, wget, curl, net-tools, lsof

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### Development Setup

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/piwlan.git
cd piwlan

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install flask flask-cors

# Run development server
sudo python3 wifi_config_server.py
```

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Designed for the Raspberry Pi photo booth community
- UI inspired by modern glassmorphism design trends
- Built with Flask for reliability and simplicity
- Thanks to all contributors and testers

## 💬 Support

For issues and questions:
- Open an issue on [GitHub](https://github.com/DJTobi24/piwlan/issues)
- Check existing issues for solutions
- Use the debug tool for diagnostics
- Review the troubleshooting section

## 🚀 Changelog

### Latest Version
- ✅ Multi-user support (not limited to 'pi' user)
- ✅ Automatic package installation
- ✅ Toggle WiFi config at startup
- ✅ Improved debug tools
- ✅ Browser auto-detection
- ✅ Connected state with direct photo booth access

### Previous Versions
- Basic WiFi configuration
- Touch interface
- Kiosk mode support

## 🔮 Future Plans

- [ ] Multiple WiFi profile support
- [ ] WiFi strength monitoring  
- [ ] Captive portal support
- [ ] Multi-language support
- [ ] Advanced network diagnostics
- [ ] REST API authentication
- [ ] Backup/restore configurations
- [ ] QR code configuration

---

Made with ❤️ for the Raspberry Pi photo booth community

**Project Link**: [https://github.com/DJTobi24/piwlan](https://github.com/DJTobi24/piwlan)

# Raspberry Pi Fotobox WiFi Configuration

A modern, touch-friendly WiFi configuration interface for Raspberry Pi-based photo booths. This solution allows users to easily connect to WiFi networks without needing SSH access or a keyboard.

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Python](https://img.shields.io/badge/python-3.7+-blue.svg)
![Raspberry Pi](https://img.shields.io/badge/Raspberry%20Pi-5-red.svg)

## 🌟 Features

- **Touch-Optimized Interface**: Large buttons and inputs designed for touchscreen use
- **Modern UI Design**: Glassmorphism effects with smooth animations
- **Auto-Discovery**: Automatically scans and displays available WiFi networks
- **Secure Connection**: Supports WPA/WPA2 encrypted networks
- **Automatic Redirect**: Redirects to photo booth application after successful connection
- **No Keyboard Required**: Complete configuration through touch interface only
- **Kiosk Mode Ready**: Designed to run in fullscreen kiosk mode

## 📋 Prerequisites

- Raspberry Pi 5 (or compatible model)
- Raspberry Pi OS (Bullseye or newer)
- Python 3.7+
- Touchscreen display
- Working photo booth application on port 3353

## 🚀 Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/DJTobi24/piwlan.git
cd piwla
```

### 2. Install Dependencies

```bash
sudo apt update
sudo apt install -y python3-pip python3-flask
sudo pip3 install flask flask-cors
```

### 3. Run Installation Script

```bash
chmod +x install.sh
sudo ./install.sh
```

Or follow the manual installation steps below.

## 📦 Manual Installation

### Step 1: Create Directory Structure

```bash
sudo mkdir -p /home/pi/wifi-config
sudo cp index.html /home/pi/wifi-config/
sudo cp wifi_config_server.py /home/pi/wifi-config/
sudo chmod +x /home/pi/wifi-config/wifi_config_server.py
```

### Step 2: Create Systemd Service

```bash
sudo cp wifi-config.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable wifi-config.service
sudo systemctl start wifi-config.service
```

### Step 3: Configure Kiosk Mode

Add to `/home/pi/.config/lxsession/LXDE-pi/autostart`:

```bash
@xset s off
@xset -dpms
@xset s noblank
@chromium-browser --kiosk --noerrdialogs --disable-infobars http://localhost:5000
```

### Step 4: Reboot

```bash
sudo reboot
```

## 🎯 Usage

1. **Power on** the Raspberry Pi with the touchscreen attached
2. **WiFi configuration page** will automatically load
3. **Select** your WiFi network from the list
4. **Enter password** using the on-screen keyboard
5. **Tap Connect** to establish connection
6. **Automatic redirect** to photo booth application upon success

## 🔧 Configuration

### Change Photo Booth URL

Edit `wifi_config_server.py`:

```python
FOTOBOX_URL = 'http://localhost:3353'  # Change to your photo booth URL
```

### Change Server Port

Edit `wifi_config_server.py`:

```python
app.run(host='0.0.0.0', port=5000)  # Change port number here
```

### Customize UI Theme

Edit the CSS variables in `index.html`:

```css
/* Change gradient colors */
background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);

/* Change accent color */
border-color: #667eea;
```

## 📁 File Structure

```
rpi-fotobox-wifi-config/
├── README.md              # This file
├── LICENSE               # MIT License
├── install.sh            # Automated installation script
├── index.html            # WiFi configuration interface
├── wifi_config_server.py # Backend server
├── wifi-config.service   # Systemd service file
└── check_connection.sh   # Connection check script
```

## 🐛 Troubleshooting

### No Networks Displayed

```bash
# Check WiFi interface
sudo iwconfig

# Check service logs
sudo journalctl -u wifi-config.service -f
```

### Connection Fails

```bash
# Check WPA supplicant logs
sudo journalctl -u wpa_supplicant -f

# Verify network interface
sudo ip link show wlan0
```

### Service Not Starting

```bash
# Check service status
sudo systemctl status wifi-config.service

# View detailed logs
sudo journalctl -xeu wifi-config.service
```

## 🔒 Security Considerations

- WiFi passwords are stored in `/etc/wpa_supplicant/wpa_supplicant.conf`
- Service runs with root privileges (required for network configuration)
- Web interface is only accessible locally by default
- Consider implementing authentication for production use

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Designed specifically for Raspberry Pi photo booth applications
- UI inspired by modern glassmorphism design trends
- Built with Flask for simplicity and reliability

## 📞 Support

For issues and questions:
- Open an issue on GitHub
- Check existing issues for solutions
- Review the troubleshooting section

---

Made with ❤️ for the Raspberry Pi photo booth community

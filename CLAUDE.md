# CLAUDE.md - AI Assistant Guide for piwlan

## Project Overview

**piwlan** is a modern, touch-friendly WiFi configuration interface for Raspberry Pi-based photo booths. It provides a web-based UI that allows users to easily connect to WiFi networks without needing SSH access or a keyboard.

**Repository**: https://github.com/DJTobi24/piwlan
**License**: MIT
**Language**: Mixed (German UI/comments, English code)
**Target Platform**: Raspberry Pi OS (Bullseye or newer)
**Primary Use Case**: Photo booth kiosks with touchscreen displays

---

## Technology Stack

| Component | Technology | Notes |
|-----------|-----------|-------|
| **Backend** | Python 3.7+ | Flask web framework |
| **Frontend** | Vanilla HTML5/CSS3/JavaScript | No frameworks, ES6+ |
| **Web Server** | Flask development server | Runs as root for network privileges |
| **Service Management** | systemd | Service runs at boot |
| **Network Tools** | wpasupplicant, wireless-tools, dhcpcd | System-level WiFi configuration |
| **UI Design** | Glassmorphism CSS | Touch-optimized, modern design |
| **Browser** | Chromium/Firefox | Auto-detected, runs in kiosk mode |

---

## Repository Structure

```
piwlan/
├── README.md                    # Comprehensive user documentation
├── LICENSE                      # MIT License
├── .gitignore                   # Python, logs, IDE files
│
├── CORE APPLICATION FILES
├── wifi_config_server.py        # Flask backend (8.2 KB, 273 lines)
├── index.html                   # Web UI (20.8 KB, single-page app)
│
├── SYSTEM CONFIGURATION
├── wifi-config.service          # systemd service definition template
│
├── INSTALLATION & SETUP
├── install.sh                   # Smart automated installer (13.8 KB, 467 lines)
│
└── UTILITY SCRIPTS
    ├── check_connection.sh      # Auto-redirect to photo booth when connected
    ├── debug_wifi_config.sh     # Interactive troubleshooting tool
    └── wifi-config-toggle.sh    # Enable/disable autostart functionality
```

### Files Created During Installation

```
/home/{user}/wifi-config/
├── index.html                   # Copy of web interface
├── wifi_config_server.py        # Customized with user ports/URLs
├── check_connection.sh          # Customized with photo booth URL
├── debug_wifi_config.sh         # Debug tool copy
└── config.txt                   # Installation summary (ports, paths, commands)

/home/{user}/.config/lxsession/LXDE-pi/
└── autostart                    # Desktop session startup config

/etc/systemd/system/
└── wifi-config.service          # System service definition

/var/log/
├── wifi-config.log              # Application logs
└── wifi-config-check.log        # Connection check logs

/etc/logrotate.d/
└── wifi-config                  # Log rotation config (7-day retention)
```

---

## Key Files Deep Dive

### 1. wifi_config_server.py (Backend API)

**Purpose**: Flask-based REST API for WiFi network operations
**Language**: Python 3, German comments
**Privileges**: Runs as root (required for network configuration)
**Location after install**: `/home/{user}/wifi-config/wifi_config_server.py`

**Configuration Variables** (lines 24-27):
```python
HTML_FILE_PATH = '/home/pi/wifi-config/index.html'  # Customized by install.sh
FOTOBOX_URL = 'http://localhost:3353'               # Customized by install.sh
CHECK_CONNECTION_TIMEOUT = 30                       # Connection wait time (seconds)
```

**API Endpoints**:

| Endpoint | Method | Function | Line | Description |
|----------|--------|----------|------|-------------|
| `/` | GET | `index()` | 161-167 | Serves HTML interface |
| `/api/networks` | GET | `get_networks()` | 169-183 | Scans and returns available WiFi networks |
| `/api/connect` | POST | `connect()` | 185-220 | Connects to specified network |
| `/api/status` | GET | `status()` | 227-243 | Returns current connection status |
| `/api/redirect` | GET | `redirect_to_fotobox()` | 222-225 | Redirects to photo booth |

**Core Functions**:
- `check_sudo()` (line 29): Validates root privileges, exits if not root
- `run_command(command)` (line 36): Shell command wrapper using subprocess
- `scan_wifi_networks()` (line 45): Uses `iwlist wlan0 scan` to discover networks
- `connect_to_wifi(ssid, password)` (line 100): Writes WPA config, restarts services
- `check_internet_connection()` (line 149): Pings 8.8.8.8 to verify connectivity
- `get_current_wifi()` (line 154): Uses `iwgetid -r` to get connected SSID

**Network Configuration Approach** (lines 103-147):
1. Generates WPA supplicant configuration with SSID and password
2. Writes to `/etc/wpa_supplicant/wpa_supplicant.conf`
3. Restarts `wpa_supplicant` and `dhcpcd` services
4. Polls for connection (30 second timeout)
5. Returns success/failure status

**Port Configuration** (lines 248-266):
- Default port: 5000
- Configurable via `WIFI_CONFIG_PORT` environment variable
- Pre-flight check for port availability
- Graceful error handling if port is occupied

### 2. index.html (Frontend UI)

**Purpose**: Single-page web application for WiFi configuration
**Language**: German UI text, English code
**Technology**: Vanilla JavaScript (no frameworks)
**Size**: 20.8 KB

**UI Sections**:
1. **Network List View** - Available WiFi networks with signal strength
2. **Connected State View** - Current network info with photo booth button
3. **Connection Form** - Password input for selected network
4. **Status Messages** - Error/success/info feedback

**JavaScript Functions**:
- `loadNetworks()` - Fetches `/api/networks`, displays network list
- `selectNetwork(ssid, security)` - Shows connection form for selected network
- `connectToNetwork()` - POSTs to `/api/connect`, handles redirect
- `checkStatus()` - Polls `/api/status` for current connection state
- `togglePasswordVisibility()` - Shows/hides password input
- `refreshNetworks()` - Manual network list refresh

**Design Features**:
- Touch-optimized with large buttons (48px+ height)
- Glassmorphism effects (backdrop-blur, transparency)
- Responsive mobile-first design
- Gradient background (#667eea to #764ba2)
- Accessible semantic HTML

### 3. install.sh (Installation Script)

**Purpose**: Fully automated setup and configuration
**Language**: Bash
**Privileges**: Requires sudo/root
**Key Feature**: Multi-user support (not hardcoded to 'pi' user)

**User Detection Logic** (lines 21-33):
```bash
if id "pi" &>/dev/null; then
    INSTALL_USER="pi"
else
    INSTALL_USER="${SUDO_USER:-$(whoami)}"
fi
USER_HOME=$(eval echo ~$INSTALL_USER)
```

**Installation Flow**:
1. **Interactive Configuration** (lines 170-216)
   - WiFi config port (default: 5000)
   - Photo booth URL (default: http://localhost:3353)
   - Validation of port numbers and URLs

2. **Package Installation** (lines 77-123)
   - Detects missing packages
   - Installs: python3, flask, wireless-tools, wpasupplicant, dhcpcd5, etc.
   - Handles broken dependencies automatically

3. **Browser Detection** (lines 126-167)
   - Auto-detects: chromium-browser, chromium, firefox-esr, firefox
   - Attempts installation if missing
   - Sets `$BROWSER_COMMAND` variable

4. **File Customization** (lines 258-302)
   - Copies files to `~/wifi-config/`
   - Uses `sed` to replace default values:
     - Port numbers in Python file
     - URLs in Python and shell scripts
   - Creates customized systemd service

5. **Service Setup** (lines 311-382)
   - Generates systemd service with correct paths
   - Enables and starts service
   - Creates log files with proper ownership

6. **Kiosk Mode Configuration** (lines 349-376)
   - Creates LXDE autostart configuration
   - Disables screen blanking (xset commands)
   - Launches browser in kiosk mode at boot
   - Adds connection check script to autostart

7. **Finalization** (lines 397-466)
   - Configures log rotation
   - Creates configuration summary file
   - Verifies service startup
   - Prompts for reboot

**Customization Points for Modifications**:
- `DEFAULT_WIFI_CONFIG_PORT=5000` (line 16)
- `DEFAULT_FOTOBOX_URL="http://localhost:3353"` (line 17)
- Package list in `packages` array (lines 81-95)
- Service security settings (lines 329-334)

### 4. wifi-config.service (systemd Service)

**Purpose**: System service definition for backend server
**Type**: systemd unit file
**Note**: Template file - install.sh creates customized version

**Key Configuration**:
```ini
[Unit]
After=network.target           # Wait for network
Wants=network.target

[Service]
Type=simple
User=root                      # Required for network configuration
WorkingDirectory={INSTALL_DIR}
ExecStart=/usr/bin/python3 {INSTALL_DIR}/wifi_config_server.py
Restart=always                 # Auto-restart on crash
RestartSec=10

# Security hardening
PrivateTmp=true               # Isolated /tmp
NoNewPrivileges=true          # Prevent privilege escalation
ProtectSystem=strict          # Read-only system directories
ProtectHome=read-only         # Read-only home directories
ReadWritePaths=/etc/wpa_supplicant /var/log  # Only writable paths
```

**Logging**:
- `StandardOutput=append:/var/log/wifi-config.log`
- `StandardError=append:/var/log/wifi-config.log`

### 5. Utility Scripts

#### check_connection.sh

**Purpose**: Auto-redirect to photo booth when internet is available
**Triggered by**: LXDE autostart (runs after desktop loads)
**Customized by**: install.sh (replaces URLs)

**Logic Flow**:
1. Wait 10 seconds for system to stabilize
2. Ping 8.8.8.8 to check internet connectivity
3. If connected: Kill chromium, launch photo booth URL in kiosk mode
4. If not connected: Do nothing (stay on WiFi config page)
5. Log status to `/var/log/wifi-config-check.log`

#### debug_wifi_config.sh

**Purpose**: Comprehensive troubleshooting and repair utility
**Privileges**: Requires sudo
**Size**: 3.7 KB

**Interactive Menu Options**:
1. Stop service & kill all processes
2. Change port to 8080 (updates files and restarts)
3. Restart service
4. Show full logs (systemd + application)
5. Test manual start on port 8888
6. Exit

**Diagnostic Checks** (shown on every run):
- Service active status and PID
- Port 5000 usage check (`lsof`)
- Running process detection (`pgrep`)
- Recent error logs extraction

#### wifi-config-toggle.sh

**Purpose**: Enable/disable WiFi config at startup
**Privileges**: Requires sudo
**Location**: Can be installed to `/usr/local/bin/wifi-config-toggle`

**Functions**:
- `disable_wifi_config()` - Comments out autostart entries, disables service
- `enable_wifi_config()` - Uncomments autostart entries, enables service
- `show_status()` - Displays current autostart and service status

---

## Development Workflows

### Local Development Setup

```bash
# Clone repository
git clone https://github.com/DJTobi24/piwlan.git
cd piwlan

# Create virtual environment (optional)
python3 -m venv venv
source venv/bin/activate

# Install Python dependencies
pip3 install flask flask-cors

# Run development server (requires root for network operations)
sudo python3 wifi_config_server.py

# Access at http://localhost:5000
```

### Testing the Application

**Manual API Testing**:
```bash
# Get available networks
curl http://localhost:5000/api/networks

# Get connection status
curl http://localhost:5000/api/status

# Connect to network
curl -X POST http://localhost:5000/api/connect \
  -H "Content-Type: application/json" \
  -d '{"ssid": "MyNetwork", "password": "mypassword"}'
```

**UI Testing**:
1. Open browser to http://localhost:5000
2. Verify network list loads
3. Test network selection
4. Test password input and visibility toggle
5. Test connection flow (requires valid WiFi credentials)

**Important**: No automated testing framework is present. All testing is manual.

### Service Management

```bash
# Start service
sudo systemctl start wifi-config.service

# Stop service
sudo systemctl stop wifi-config.service

# Restart service
sudo systemctl restart wifi-config.service

# Enable at boot
sudo systemctl enable wifi-config.service

# Disable at boot
sudo systemctl disable wifi-config.service

# View status
sudo systemctl status wifi-config.service

# View logs (live)
sudo journalctl -u wifi-config.service -f

# View logs (last 50 lines)
sudo journalctl -u wifi-config.service -n 50

# View application log
sudo tail -f /var/log/wifi-config.log
```

### Making Changes to the Codebase

#### Modifying the Backend (wifi_config_server.py)

**After editing**:
```bash
# If installed via install.sh, edit the installed version
sudo nano ~/wifi-config/wifi_config_server.py

# Restart service to apply changes
sudo systemctl restart wifi-config.service

# Monitor logs for errors
sudo journalctl -u wifi-config.service -f
```

**Key areas to be careful with**:
- Line 25: `HTML_FILE_PATH` - must point to valid HTML file
- Line 26: `FOTOBOX_URL` - photo booth redirect destination
- Line 249: Port configuration - ensure no conflicts
- Lines 100-147: WiFi connection logic - requires root, modifies system files

#### Modifying the Frontend (index.html)

**After editing**:
```bash
# If installed via install.sh, edit the installed version
sudo nano ~/wifi-config/index.html

# No service restart needed - refresh browser
# Hard refresh: Ctrl+Shift+R or Ctrl+F5
```

**Key areas**:
- CSS starting around `<style>` tag - modify colors, sizes, animations
- JavaScript functions - modify API calls, UI behavior
- HTML structure - modify layout, add new elements
- Language strings - currently in German, easily translatable

#### Modifying Installation (install.sh)

**Testing changes**:
```bash
# Make backup first
cp install.sh install.sh.backup

# Edit install.sh
nano install.sh

# Test on a clean system or VM
sudo ./install.sh

# Verify installation
sudo systemctl status wifi-config.service
cat ~/wifi-config/config.txt
```

**Common modifications**:
- Add new packages to `packages` array (line 81)
- Change default port/URL (lines 16-17)
- Modify service security settings (lines 329-334)
- Add additional configuration steps

---

## Coding Conventions and Patterns

### Python Backend Conventions

**Style**:
- PEP 8 compliance (mostly)
- German comments and docstrings
- Function names in snake_case
- Logging via Python logging module

**Error Handling Pattern**:
```python
try:
    # Operation
    result = operation()
    return jsonify({'success': True, 'data': result})
except Exception as e:
    logger.error(f"Error description: {e}")
    return jsonify({'success': False, 'error': str(e)}), 500
```

**Shell Command Execution Pattern**:
```python
stdout, stderr, returncode = run_command("command here")
if returncode != 0:
    logger.error(f"Error: {stderr}")
    return error_response
```

### Frontend JavaScript Conventions

**Style**:
- Vanilla JavaScript (ES6+)
- German UI text
- Async/await for API calls
- DOM manipulation via document.querySelector

**API Call Pattern**:
```javascript
async function apiCall() {
    try {
        const response = await fetch('/api/endpoint', {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify(data)
        });
        const result = await response.json();
        if (result.success) {
            // Handle success
        } else {
            // Handle error
        }
    } catch (error) {
        console.error('Error:', error);
        showMessage('Fehler: ' + error.message, 'error');
    }
}
```

**UI Update Pattern**:
```javascript
function updateUI() {
    const container = document.getElementById('container');
    container.innerHTML = ''; // Clear
    data.forEach(item => {
        const element = document.createElement('div');
        element.textContent = item.name;
        container.appendChild(element);
    });
}
```

### Bash Script Conventions

**Style**:
- `set -e` for fail-fast behavior
- Color-coded output using ANSI codes
- Functions for reusable logic
- German output messages (user-facing)

**Output Pattern**:
```bash
print_status() { echo -e "${GREEN}[+]${NC} $1"; }
print_error() { echo -e "${RED}[!]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[*]${NC} $1"; }
print_info() { echo -e "${BLUE}[i]${NC} $1"; }
```

**User Detection Pattern** (used in install.sh and wifi-config-toggle.sh):
```bash
if id "pi" &>/dev/null; then
    INSTALL_USER="pi"
else
    INSTALL_USER="${SUDO_USER:-$(whoami)}"
fi
USER_HOME=$(eval echo ~$INSTALL_USER)
```

---

## Common Tasks for AI Assistants

### Task 1: Change Default Port

**Files to modify**:
1. `install.sh` - line 16: `DEFAULT_WIFI_CONFIG_PORT=5000`
2. `wifi_config_server.py` - line 249: `port = int(os.environ.get('WIFI_CONFIG_PORT', 5000))`

**For already installed systems**:
```bash
# Edit installed files
sudo nano ~/wifi-config/wifi_config_server.py
# Change port in app.run() call (line 266)

# Update autostart
nano ~/.config/lxsession/LXDE-pi/autostart
# Change http://localhost:5000 to new port

# Restart service
sudo systemctl restart wifi-config.service
```

### Task 2: Add New API Endpoint

**Location**: `wifi_config_server.py`

**Pattern to follow**:
```python
@app.route('/api/newendpoint', methods=['GET'])
def new_endpoint():
    """German description of endpoint purpose"""
    try:
        # Your logic here
        result = do_something()
        return jsonify({
            'success': True,
            'data': result
        })
    except Exception as e:
        logger.error(f"Fehler in new_endpoint: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500
```

**Then update frontend** in `index.html`:
```javascript
async function callNewEndpoint() {
    try {
        const response = await fetch('/api/newendpoint');
        const data = await response.json();
        // Handle data
    } catch (error) {
        console.error('Error:', error);
    }
}
```

### Task 3: Translate UI to English

**File**: `index.html`

**Strings to translate** (search for these in HTML):
- "Mit WLAN verbunden" → "Connected to WiFi"
- "Zur Fotobox →" → "To Photo Booth →"
- "Anderes WLAN wählen" → "Choose Different WiFi"
- "Verfügbare Netzwerke" → "Available Networks"
- "WLAN-Passwort" → "WiFi Password"
- "Verbinden" → "Connect"
- "Abbrechen" → "Cancel"
- "Netzwerke werden geladen..." → "Loading networks..."

**Also translate JavaScript messages**:
- Search for `showMessage` calls
- Update German error messages to English

### Task 4: Add Support for 5GHz Networks

**Current limitation**: Code uses `iwlist wlan0 scan` which may not detect all frequencies.

**Files to modify**:
1. `wifi_config_server.py` - `scan_wifi_networks()` function (line 45)

**Improvements needed**:
- Check for both wlan0 and wlan1 interfaces
- Parse frequency information from scan results
- Display frequency band in UI (2.4GHz vs 5GHz)

**Example modification**:
```python
def scan_wifi_networks():
    networks = []
    # Check all wireless interfaces
    for interface in ['wlan0', 'wlan1']:
        stdout, stderr, returncode = run_command(f"sudo iwlist {interface} scan")
        if returncode == 0:
            # Parse results (add frequency extraction)
            # Add to networks list
    return networks
```

### Task 5: Add Network Reconnection Logic

**Use case**: Remember previously connected networks and auto-reconnect

**Files to modify**:
1. `wifi_config_server.py` - `connect_to_wifi()` function
2. `check_connection.sh` - Add network checking logic

**Implementation approach**:
- Append to WPA config instead of overwriting (support multiple networks)
- Set network priority
- Add endpoint to list saved networks
- Add UI to manage saved networks

### Task 6: Add API Authentication

**Current state**: No authentication (localhost-only mitigates risk)

**Implementation approach**:
1. Generate API token on installation
2. Store in config file (not in git)
3. Require token in request headers
4. Validate on each API call

**Files to modify**:
1. `wifi_config_server.py` - Add authentication decorator
2. `index.html` - Add token to fetch requests
3. `install.sh` - Generate token during installation

---

## Important Notes and Gotchas

### Security Considerations

⚠️ **Root Privileges Required**:
- Backend server runs as root (needed for WiFi configuration)
- Service has limited write access (only `/etc/wpa_supplicant` and `/var/log`)
- Be cautious with shell command execution

⚠️ **No API Authentication**:
- Web interface is accessible to anyone on local network
- Passwords transmitted in plain text over HTTP
- Mitigated by running in kiosk mode on local device

⚠️ **WiFi Credentials Storage**:
- Stored in plain text in `/etc/wpa_supplicant/wpa_supplicant.conf`
- Standard Linux WiFi configuration practice
- Readable only by root

⚠️ **Command Injection Risk**:
- SSID and password values used in shell commands
- Currently not sanitized
- **Risk**: Malicious SSID with shell metacharacters could execute commands
- **Mitigation needed**: Escape or validate inputs before shell execution

**Recommended improvements**:
1. Add input validation/sanitization for SSID and password
2. Use parameterized commands instead of string interpolation
3. Add HTTPS support for password transmission
4. Implement API token authentication
5. Add rate limiting to prevent brute force

### Language and Localization

🌐 **Current Language**: German
- UI text in `index.html`
- Error messages in `wifi_config_server.py`
- Script output in `.sh` files

**For English version**:
- Translate strings in HTML file
- Update Python logger messages
- Update bash script echo statements
- Consider using i18n library for multi-language support

### Multi-User Support

✅ **Not Hardcoded to 'pi' User**:
- `install.sh` detects current user via `$SUDO_USER`
- `wifi-config-toggle.sh` has same logic
- All paths use detected user's home directory

**User detection logic**:
```bash
if id "pi" &>/dev/null; then
    INSTALL_USER="pi"
else
    INSTALL_USER="${SUDO_USER:-$(whoami)}"
fi
USER_HOME=$(eval echo ~$INSTALL_USER)
```

### Port Configuration

🔌 **Configurable Ports**:
- Default WiFi config port: 5000
- Configured during installation via interactive prompt
- Stored in multiple locations:
  - `wifi_config_server.py` (hardcoded default and env var)
  - `wifi-config.service` (environment variable)
  - `autostart` (browser URL)
  - `config.txt` (documentation)

**To change port after installation**:
Must update all 4 locations manually, or use `debug_wifi_config.sh` option 2.

### Browser Compatibility

🌐 **Supported Browsers**:
- Chromium Browser (preferred)
- Chromium
- Firefox ESR
- Firefox

**Kiosk Mode Flags**:
- `--kiosk` - Fullscreen without browser chrome
- `--noerrdialogs` - Suppress error dialogs
- `--disable-infobars` - Hide info bars

**Auto-detection**: `install.sh` detects available browser and sets command in autostart.

### Network Interface Names

📡 **Assumed Interface**: `wlan0`
- Hardcoded in `wifi_config_server.py` (lines 50, scan command)
- May not work if interface has different name (e.g., wlan1, wlp2s0)

**To support different interfaces**:
1. Detect available wireless interfaces dynamically
2. Use first available wireless interface
3. Or make interface name configurable

**Detection command**:
```bash
# List wireless interfaces
iw dev | grep Interface | awk '{print $2}'
```

### Service Auto-Restart Behavior

🔄 **Restart Policy**: `Restart=always`
- Service automatically restarts on crash
- 10-second delay between restarts (`RestartSec=10`)
- Useful for development (auto-recovery)
- May mask underlying issues

**To debug persistent failures**:
1. Use `sudo systemctl stop wifi-config.service`
2. Run manually: `sudo python3 ~/wifi-config/wifi_config_server.py`
3. Observe error output directly

### Filesystem Paths

📁 **Paths to Watch**:
- `/home/pi/` appears in some default values
- `install.sh` customizes these during installation
- Never assume 'pi' user exists - use detected user path

**Path variables**:
- `$INSTALL_USER` - Detected username
- `$USER_HOME` - User's home directory
- `$INSTALL_DIR` - Installation directory (usually `$USER_HOME/wifi-config`)

### Git Workflow

🔀 **Branch Strategy**:
- Main branch for releases
- Feature branches for development
- No specific branch naming convention documented

**Commit Messages**:
- No specific convention documented
- Recommend descriptive messages in English

**When committing changes**:
```bash
# Add changes
git add <files>

# Commit with descriptive message
git commit -m "Description of changes"

# Push to remote
git push origin <branch-name>
```

### Testing Limitations

⚠️ **No Automated Tests**:
- No pytest, unittest, or testing framework
- All testing is manual
- No CI/CD pipeline

**Testing checklist for changes**:
1. ✅ Service starts without errors
2. ✅ Web interface loads at http://localhost:5000
3. ✅ Network scan works and displays networks
4. ✅ Connection to WiFi succeeds with valid credentials
5. ✅ Connection fails gracefully with invalid credentials
6. ✅ Redirect to photo booth works after connection
7. ✅ Logs show expected information
8. ✅ Service restarts automatically after crash
9. ✅ Installation script completes without errors
10. ✅ Kiosk mode launches correctly after reboot

---

## Architecture Patterns

### Backend Architecture

**Pattern**: Simple REST API with synchronous processing

```
User Browser
     ↓
  Flask Server (Python)
     ↓
  System Commands (subprocess)
     ↓
  WiFi Hardware (wlan0)
```

**Characteristics**:
- No database (stateless)
- No caching layer
- Synchronous blocking operations
- Direct system command execution
- Simple request/response model

### Frontend Architecture

**Pattern**: Single-page application with vanilla JavaScript

```
HTML Structure
     ↓
CSS Styling (embedded)
     ↓
JavaScript Logic (embedded)
     ↓
Fetch API calls to backend
     ↓
DOM manipulation for updates
```

**Characteristics**:
- No build process
- No bundler or transpiler
- No frameworks or libraries
- Direct DOM manipulation
- Async/await for network calls

### Service Architecture

**Pattern**: systemd managed daemon

```
System Boot
     ↓
systemd starts multi-user.target
     ↓
wifi-config.service starts
     ↓
Python server runs continuously
     ↓
Auto-restarts on failure
```

**Desktop Session Flow**:

```
User Login
     ↓
LXDE Desktop Starts
     ↓
autostart file executes
     ↓
Browser launches in kiosk mode
     ↓
check_connection.sh runs
     ↓
Redirects to photo booth if connected
```

---

## Dependencies and Package Management

### Python Dependencies

**Managed via**: pip3
**Installation**: Global system packages (not virtualenv)

```
flask          # Web framework
flask-cors     # CORS support for API
```

**No requirements.txt** - Dependencies installed by `install.sh`

### System Dependencies

**Managed via**: apt (Debian package manager)

```
python3              # Python runtime
python3-pip          # Python package installer
git                  # Version control
wget, curl           # HTTP clients
net-tools            # Network utilities
wireless-tools       # WiFi scanning (iwlist, iwgetid)
wpasupplicant        # WiFi authentication
dhcpcd5              # DHCP client
systemd              # Service management
lsof                 # Port checking
chromium-browser     # Web browser (or firefox-esr)
```

### Browser Dependencies

**Auto-detected in order**:
1. chromium-browser (Raspberry Pi default)
2. chromium (generic Linux)
3. firefox (generic Linux)
4. firefox-esr (Debian/Raspberry Pi OS)

---

## Configuration Files Summary

| File | Purpose | Format | Modified By |
|------|---------|--------|-------------|
| `~/wifi-config/config.txt` | Installation summary | Text | install.sh |
| `/etc/systemd/system/wifi-config.service` | Service definition | systemd unit | install.sh |
| `~/.config/lxsession/LXDE-pi/autostart` | Desktop autostart | Shell script | install.sh, toggle script |
| `/etc/wpa_supplicant/wpa_supplicant.conf` | WiFi credentials | WPA config | Backend API |
| `/etc/logrotate.d/wifi-config` | Log rotation | logrotate config | install.sh |

---

## Troubleshooting Guide for AI Assistants

### Problem: Service won't start

**Diagnostic steps**:
```bash
# Check service status
sudo systemctl status wifi-config.service

# View logs
sudo journalctl -u wifi-config.service -n 50

# Check for errors
sudo tail -20 /var/log/wifi-config.log

# Test manual start
cd ~/wifi-config
sudo python3 wifi_config_server.py
```

**Common causes**:
- Port already in use
- Python dependencies missing
- File permissions incorrect
- HTML file not found
- Not running as root

### Problem: Port already in use

**Diagnostic**:
```bash
# Check what's using port 5000
sudo lsof -i :5000

# Find all python processes
pgrep -fa python
```

**Solution**:
```bash
# Kill old processes
sudo pkill -f wifi_config_server.py

# Or use debug script
sudo ~/wifi-config/debug_wifi_config.sh
# Select option 1 to kill all processes
```

### Problem: No networks displayed

**Diagnostic**:
```bash
# Check WiFi interface exists
iwconfig

# Test manual scan
sudo iwlist wlan0 scan

# Check if wlan0 is up
ip link show wlan0
```

**Common causes**:
- Wrong interface name (not wlan0)
- WiFi disabled in hardware
- Insufficient permissions
- Driver issues

### Problem: Can't connect to network

**Diagnostic**:
```bash
# Check WPA supplicant status
sudo systemctl status wpa_supplicant

# Check DHCP client
sudo systemctl status dhcpcd

# View WPA config
sudo cat /etc/wpa_supplicant/wpa_supplicant.conf

# Check interface status
sudo wpa_cli status
```

**Common causes**:
- Wrong password
- Network out of range
- Unsupported security type
- DHCP server not responding
- Services not running

### Problem: Browser doesn't launch in kiosk mode

**Diagnostic**:
```bash
# Check autostart file
cat ~/.config/lxsession/LXDE-pi/autostart

# Test browser manually
DISPLAY=:0 chromium-browser --kiosk http://localhost:5000
```

**Common causes**:
- Browser not installed
- Wrong browser command
- Display not set
- Service not running
- Port incorrect in URL

---

## Future Development Ideas

Based on README.md "Future Plans" section:

1. **Multiple WiFi Profiles** - Store and switch between networks
2. **WiFi Strength Monitoring** - Real-time signal strength display
3. **Captive Portal Support** - Handle hotel/public WiFi login
4. **Multi-language Support** - i18n framework for translations
5. **Advanced Network Diagnostics** - Ping tests, DNS checks, traceroute
6. **REST API Authentication** - Token-based auth for security
7. **Backup/Restore Configurations** - Export/import WiFi profiles
8. **QR Code Configuration** - Scan QR to configure WiFi

**Recommended approach for new features**:
- Add new API endpoints in `wifi_config_server.py`
- Add new UI sections in `index.html`
- Update documentation in `README.md`
- Consider backward compatibility with existing installations
- Add configuration options to `install.sh` if needed

---

## Contact and Support

**Issues**: https://github.com/DJTobi24/piwlan/issues
**Repository**: https://github.com/DJTobi24/piwlan
**License**: MIT
**Author**: DJTobi24

---

## Quick Reference for AI Assistants

### Essential Commands

```bash
# Installation
sudo ./install.sh

# Service management
sudo systemctl start|stop|restart|status wifi-config.service
sudo journalctl -u wifi-config.service -f

# Debugging
sudo ~/wifi-config/debug_wifi_config.sh
sudo tail -f /var/log/wifi-config.log

# Toggle startup
sudo wifi-config-toggle

# Manual testing
sudo python3 ~/wifi-config/wifi_config_server.py
curl http://localhost:5000/api/networks
```

### Key File Locations

```bash
# Application files
~/wifi-config/index.html
~/wifi-config/wifi_config_server.py
~/wifi-config/check_connection.sh
~/wifi-config/config.txt

# System files
/etc/systemd/system/wifi-config.service
~/.config/lxsession/LXDE-pi/autostart
/var/log/wifi-config.log
/etc/wpa_supplicant/wpa_supplicant.conf
```

### Code Modification Checklist

When modifying the codebase:

- [ ] Read existing code to understand patterns
- [ ] Follow existing naming conventions
- [ ] Use German for user-facing messages (or translate all to English)
- [ ] Test manually (no automated tests available)
- [ ] Check service restarts successfully
- [ ] Verify logs show expected output
- [ ] Update documentation if adding features
- [ ] Consider security implications (runs as root)
- [ ] Validate user inputs to prevent injection
- [ ] Test on Raspberry Pi hardware if possible

---

**Document Version**: 1.0
**Last Updated**: 2025-11-17
**Codebase Version**: Based on latest commit 24ce95b

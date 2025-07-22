#!/usr/bin/env python3
"""
WLAN Konfigurations-Backend für Raspberry Pi Fotobox
Ermöglicht das Scannen und Verbinden mit WLAN-Netzwerken über eine Web-Oberfläche
"""

from flask import Flask, jsonify, request, send_file, redirect
from flask_cors import CORS
import subprocess
import re
import time
import os
import sys
import json
import logging

app = Flask(__name__)
CORS(app)

# Logging konfigurieren
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Konfiguration
HTML_FILE_PATH = '/home/pi/wifi-config/index.html'
FOTOBOX_URL = 'http://localhost:3353'
CHECK_CONNECTION_TIMEOUT = 30  # Sekunden

def check_sudo():
    """Überprüft ob das Script mit sudo-Rechten läuft"""
    if os.geteuid() != 0:
        print("Dieses Script muss mit sudo-Rechten ausgeführt werden!")
        print("Bitte starte es mit: sudo python3 wifi_config_server.py")
        sys.exit(1)

def run_command(command):
    """Führt einen Shell-Befehl aus und gibt das Ergebnis zurück"""
    try:
        result = subprocess.run(command, shell=True, capture_output=True, text=True)
        return result.stdout.strip(), result.stderr.strip(), result.returncode
    except Exception as e:
        logger.error(f"Fehler beim Ausführen des Befehls: {e}")
        return "", str(e), 1

def scan_wifi_networks():
    """Scannt nach verfügbaren WLAN-Netzwerken"""
    networks = []
    
    # Führe iwlist scan aus
    stdout, stderr, returncode = run_command("sudo iwlist wlan0 scan")
    
    if returncode != 0:
        logger.error(f"Fehler beim Scannen: {stderr}")
        return networks
    
    # Parse die Ausgabe
    current_network = {}
    for line in stdout.split('\n'):
        line = line.strip()
        
        # Neue Zelle gefunden
        if line.startswith('Cell'):
            if current_network and 'ssid' in current_network:
                networks.append(current_network)
            current_network = {}
        
        # ESSID extrahieren
        elif 'ESSID:' in line:
            match = re.search(r'ESSID:"(.+)"', line)
            if match:
                current_network['ssid'] = match.group(1)
        
        # Signalstärke extrahieren
        elif 'Signal level=' in line:
            match = re.search(r'Signal level=(-?\d+)', line)
            if match:
                current_network['signal'] = int(match.group(1))
        
        # Verschlüsselung extrahieren
        elif 'Encryption key:' in line:
            if 'on' in line:
                current_network['security'] = 'WPA2'  # Vereinfacht
            else:
                current_network['security'] = 'Open'
    
    # Letztes Netzwerk hinzufügen
    if current_network and 'ssid' in current_network:
        networks.append(current_network)
    
    # Duplikate entfernen und nach Signalstärke sortieren
    seen = set()
    unique_networks = []
    for network in sorted(networks, key=lambda x: x.get('signal', -100), reverse=True):
        if network['ssid'] and network['ssid'] not in seen:
            seen.add(network['ssid'])
            unique_networks.append(network)
    
    return unique_networks

def connect_to_wifi(ssid, password=None):
    """Verbindet sich mit einem WLAN-Netzwerk"""
    try:
        # Erstelle wpa_supplicant Konfiguration
        wpa_config = f'''
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=DE

network={{
    ssid="{ssid}"'''
        
        if password:
            wpa_config += f'''
    psk="{password}"'''
        else:
            wpa_config += '''
    key_mgmt=NONE'''
        
        wpa_config += '''
}
'''
        
        # Schreibe Konfiguration
        config_path = '/etc/wpa_supplicant/wpa_supplicant.conf'
        with open(config_path, 'w') as f:
            f.write(wpa_config)
        
        logger.info(f"WPA Supplicant Konfiguration für {ssid} geschrieben")
        
        # Starte WLAN-Interface neu
        run_command("sudo systemctl restart wpa_supplicant")
        time.sleep(2)
        run_command("sudo systemctl restart dhcpcd")
        
        # Warte auf Verbindung
        for i in range(CHECK_CONNECTION_TIMEOUT):
            time.sleep(1)
            if check_internet_connection():
                logger.info(f"Erfolgreich mit {ssid} verbunden")
                return True
        
        logger.error(f"Timeout beim Verbinden mit {ssid}")
        return False
        
    except Exception as e:
        logger.error(f"Fehler beim Verbinden: {e}")
        return False

def check_internet_connection():
    """Überprüft ob eine Internetverbindung besteht"""
    stdout, stderr, returncode = run_command("ping -c 1 -W 2 8.8.8.8")
    return returncode == 0

def get_current_wifi():
    """Gibt das aktuell verbundene WLAN zurück"""
    stdout, stderr, returncode = run_command("iwgetid -r")
    if returncode == 0 and stdout:
        return stdout
    return None

@app.route('/')
def index():
    """Zeigt die HTML-Seite an"""
    if os.path.exists(HTML_FILE_PATH):
        return send_file(HTML_FILE_PATH)
    else:
        return "HTML-Datei nicht gefunden", 404

@app.route('/api/networks', methods=['GET'])
def get_networks():
    """API-Endpunkt zum Abrufen verfügbarer Netzwerke"""
    try:
        networks = scan_wifi_networks()
        return jsonify({
            'success': True,
            'networks': networks,
            'current': get_current_wifi()
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/connect', methods=['POST'])
def connect():
    """API-Endpunkt zum Verbinden mit einem Netzwerk"""
    try:
        data = request.json
        ssid = data.get('ssid')
        password = data.get('password', '')
        
        if not ssid:
            return jsonify({
                'success': False,
                'error': 'SSID fehlt'
            }), 400
        
        logger.info(f"Verbindungsversuch mit {ssid}")
        
        success = connect_to_wifi(ssid, password)
        
        if success:
            # Bei Erfolg zur Fotobox weiterleiten
            return jsonify({
                'success': True,
                'redirect': FOTOBOX_URL
            })
        else:
            return jsonify({
                'success': False,
                'error': 'Verbindung fehlgeschlagen'
            }), 400
            
    except Exception as e:
        logger.error(f"Fehler beim Verbinden: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/redirect', methods=['GET'])
def redirect_to_fotobox():
    """Leitet zur Fotobox weiter"""
    return redirect(FOTOBOX_URL)

@app.route('/api/status', methods=['GET'])
def status():
    """API-Endpunkt zum Abrufen des Verbindungsstatus"""
    try:
        connected = check_internet_connection()
        current_ssid = get_current_wifi()
        
        return jsonify({
            'success': True,
            'connected': connected,
            'ssid': current_ssid
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

if __name__ == '__main__':
    check_sudo()
    
    # Port aus Umgebungsvariable oder Standard
    port = int(os.environ.get('WIFI_CONFIG_PORT', 5000))
    
    # Prüfe ob Port bereits belegt ist
    import socket
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    result = sock.connect_ex(('127.0.0.1', port))
    sock.close()
    
    if result == 0:
        logger.error(f"Port {port} ist bereits belegt!")
        logger.error("Beende alte Prozesse mit: sudo pkill -f wifi_config_server.py")
        logger.error(f"Oder verwende einen anderen Port: WIFI_CONFIG_PORT=8080 python3 {sys.argv[0]}")
        sys.exit(1)
    
    logger.info(f"WLAN Konfigurations-Server gestartet auf Port {port}")
    
    try:
        app.run(host='0.0.0.0', port=port, debug=False)
    except OSError as e:
        if e.errno == 98:  # Address already in use
            logger.error(f"Port {port} ist bereits belegt! Verwende einen anderen Port.")
            sys.exit(1)
        else:
            raise

#!/bin/bash
# Skrypt do automatycznej konfiguracji services z wykryciem usera

set -e

echo "=== Konfiguracja WiFi Kiosk Services (auto-detect user) ==="
echo ""

# Wykryj aktualnego usera i jego home directory
CURRENT_USER=$(whoami)
USER_HOME=$(eval echo "~$CURRENT_USER")
PROJECT_PATH="$USER_HOME/wifi-kiosk"

echo "Wykryty user: $CURRENT_USER"
echo "Home directory: $USER_HOME"
echo "Ścieżka projektu: $PROJECT_PATH"
echo ""

# Sprawdź czy projekt istnieje
if [ ! -f "$PROJECT_PATH/backend/server.js" ]; then
    echo "BŁĄD: Nie znaleziono projektu w $PROJECT_PATH"
    echo "Sklonuj projekt do $PROJECT_PATH lub zmień katalog"
    exit 1
fi

# Sprawdź czy curl jest zainstalowany (potrzebny dla start-kiosk.sh)
if ! command -v curl >/dev/null 2>&1; then
    echo "Instaluję curl (potrzebny dla skryptów)..."
    sudo apt install -y curl
fi

# Utwórz service dla backendu (zawsze jako root)
echo "Tworzenie service dla backendu..."
sudo tee /etc/systemd/system/wifi-kiosk-backend.service > /dev/null << EOF
[Unit]
Description=WiFi Kiosk Backend Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$PROJECT_PATH/backend
ExecStart=/usr/bin/node $PROJECT_PATH/backend/server.js
Restart=always
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=wifi-kiosk-backend

# Zmienne środowiskowe
Environment="NODE_ENV=production"
Environment="PORT=80"

[Install]
WantedBy=multi-user.target
EOF

# Utwórz service dla GUI (jako aktualny user)
echo "Tworzenie service dla GUI..."
sudo tee /etc/systemd/system/wifi-kiosk-gui.service > /dev/null << EOF
[Unit]
Description=WiFi Kiosk GUI (Chromium Kiosk Mode)
After=graphical.target wifi-kiosk-backend.service
Wants=graphical.target
Requires=wifi-kiosk-backend.service

[Service]
Type=simple
User=$CURRENT_USER
Environment="DISPLAY=:0"
Environment="XAUTHORITY=$USER_HOME/.Xauthority"
ExecStartPre=/bin/sleep 10
ExecStart=/bin/bash $PROJECT_PATH/scripts/start-kiosk.sh
Restart=always
RestartSec=10

[Install]
WantedBy=graphical.target
EOF

# Przeładuj systemd
echo "Przeładowanie systemd..."
sudo systemctl daemon-reload

# Włącz services
echo "Włączanie services..."
sudo systemctl enable wifi-kiosk-backend.service

# GUI service włączaj tylko jeśli jest środowisko graficzne
if systemctl get-default | grep -q graphical; then
    sudo systemctl enable wifi-kiosk-gui.service
    echo "GUI service włączone (wykryto środowisko graficzne)"
else
    echo "GUI service nie włączono (brak środowiska graficznego)"
    echo "Na Lite OS GUI uruchomi się przez .xinitrc"
fi

# Uruchom backend
echo "Uruchamianie backend service..."
sudo systemctl start wifi-kiosk-backend.service

# Sprawdź status
echo ""
echo "=== Status services ==="
sudo systemctl status wifi-kiosk-backend.service --no-pager
echo ""

# Konfiguracja dodatkowa
echo "=== Konfiguracja dodatkowa ==="

# Autologowanie
echo "Czy chcesz skonfigurować automatyczne logowanie? (t/n)"
read -r response
if [[ "$response" =~ ^([tT][aA][kK]|[tT])$ ]]; then
    echo "Konfiguracja autologowania dla usera: $CURRENT_USER"
    
    # Ustaw autologowanie dla aktualnego usera
    sudo raspi-config nonint do_boot_behaviour B4
    
    # W nowszych wersjach może być potrzebna inna konfiguracja
    if [ -f /etc/systemd/system/getty@tty1.service.d/autologin.conf ]; then
        sudo sed -i "s/pi/$CURRENT_USER/g" /etc/systemd/system/getty@tty1.service.d/autologin.conf
    fi
    
    echo "Autologowanie skonfigurowane dla usera: $CURRENT_USER"
fi

echo ""
echo "=== Konfiguracja zakończona! ==="
echo ""
echo "Backend działa jako: root (wymagane do konfiguracji WiFi)"
echo "GUI działa jako: $CURRENT_USER"
echo "Projekt w: $PROJECT_PATH"
echo ""
echo "Komendy:"
echo "sudo systemctl status wifi-kiosk-backend"
echo "sudo systemctl status wifi-kiosk-gui"
echo ""
echo "Po rebotowaniu system uruchomi się automatycznie."
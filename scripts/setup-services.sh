#!/bin/bash
# Skrypt do instalacji i konfiguracji services systemd
# UWAGA: Przestarzały - użyj configure-services.sh

echo "=== UWAGA: Ten skrypt używa hardcoded ścieżek ==="
echo "Zalecane jest użycie nowego skryptu który automatycznie wykrywa usera:"
echo "./scripts/configure-services.sh"
echo ""
echo "Czy chcesz użyć nowego skryptu? (t/n)"
read -r response

if [[ "$response" =~ ^([tT][aA][kK]|[tT])$ ]]; then
    echo "Uruchamianie nowego skryptu..."
    exec ./scripts/configure-services.sh
    exit 0
fi

echo "=== Konfiguracja WiFi Kiosk Services (stary tryb) ==="

# Wykryj aktualnego usera
CURRENT_USER=$(whoami)
USER_HOME=$(eval echo "~$CURRENT_USER")
PROJECT_PATH="$USER_HOME/wifi-kiosk"

echo "Wykryty user: $CURRENT_USER"
echo "Ścieżka projektu: $PROJECT_PATH"

# Sprawdź czy projekt istnieje
if [ ! -f "$PROJECT_PATH/backend/server.js" ]; then
    echo "BŁĄD: Nie znaleziono projektu w $PROJECT_PATH"
    echo "Upewnij się, że projekt jest sklonowany do $PROJECT_PATH"
    exit 1
fi

# Utwórz service dla backendu dynamicznie
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

Environment="NODE_ENV=production"
Environment="PORT=80"

[Install]
WantedBy=multi-user.target
EOF

# Utwórz service dla GUI dynamicznie
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
sudo systemctl enable wifi-kiosk-gui.service

# Uruchom backend
echo "Uruchamianie backend service..."
sudo systemctl start wifi-kiosk-backend.service

# Sprawdź status
echo ""
echo "=== Status services ==="
sudo systemctl status wifi-kiosk-backend.service --no-pager
echo ""

# Konfiguracja autologowania
echo "Czy chcesz skonfigurować automatyczne logowanie dla $CURRENT_USER? (t/n)"
read -r response
if [[ "$response" =~ ^([tT][aA][kK]|[tT])$ ]]; then
    echo "Konfiguracja autologowania..."
    sudo raspi-config nonint do_boot_behaviour B4
    echo "Autologowanie włączone dla usera: $CURRENT_USER"
fi

# Wyłączenie wygaszacza ekranu
echo "Czy chcesz wyłączyć wygaszacz ekranu? (t/n)"
read -r response
if [[ "$response" =~ ^([tT][aA][kK]|[tT])$ ]]; then
    if [ -f /etc/lightdm/lightdm.conf ]; then
        if ! grep -q "xserver-command=X -s 0 -dpms" /etc/lightdm/lightdm.conf; then
            sudo sed -i '/\[Seat:\*\]/a xserver-command=X -s 0 -dpms' /etc/lightdm/lightdm.conf
            echo "Wygaszacz ekranu wyłączony!"
        else
            echo "Wygaszacz ekranu już jest wyłączony"
        fi
    fi
fi

echo ""
echo "=== Instalacja zakończona! ==="
echo ""
echo "Backend działa jako: root"
echo "GUI działa jako: $CURRENT_USER"
echo ""
echo "Komendy:"
echo "sudo systemctl status wifi-kiosk-backend"
echo "sudo systemctl status wifi-kiosk-gui"
echo ""
echo "Logi:"
echo "sudo journalctl -u wifi-kiosk-backend -f"
echo "sudo journalctl -u wifi-kiosk-gui -f"
echo ""
echo "Uruchom ponownie Raspberry Pi aby zastosować wszystkie zmiany:"
echo "sudo reboot"
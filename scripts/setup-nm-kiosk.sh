#!/bin/bash
# Konfiguracja NetworkManager dla aplikacji kiosk

set -e

echo "=== Konfiguracja NetworkManager dla aplikacji kiosk ==="

# 1. Zatrzymaj i wyłącz konfliktujące usługi
echo "Wyłączanie konfliktujących usług..."
sudo systemctl stop hostapd dnsmasq wpa_supplicant 2>/dev/null || true
sudo systemctl disable hostapd dnsmasq 2>/dev/null || true
sudo systemctl mask hostapd dnsmasq 2>/dev/null || true

# 2. Instalacja NetworkManager jeśli nie ma
if ! command -v nmcli &> /dev/null; then
    echo "Instalacja NetworkManager..."
    sudo apt update
    sudo apt install -y network-manager
fi

# 3. Konfiguracja NetworkManager
echo "Konfiguracja NetworkManager..."
sudo tee /etc/NetworkManager/NetworkManager.conf > /dev/null <<EOF
[main]
plugins=keyfile
dhcp=internal

[device]
wifi.backend=wpa_supplicant

[logging]
level=WARN
EOF

# 4. Wyłącz zarządzanie eth0 przez NetworkManager (pozostaw dla internetu)
sudo tee /etc/NetworkManager/conf.d/10-ignore-eth.conf > /dev/null <<EOF
[keyfile]
unmanaged-devices=interface-name:eth0
EOF

# 5. Włącz i uruchom NetworkManager
echo "Uruchamianie NetworkManager..."
sudo systemctl unmask NetworkManager
sudo systemctl enable NetworkManager
sudo systemctl restart NetworkManager

# 6. Poczekaj na uruchomienie
sleep 5

# 7. Upewnij się że wlan0 jest zarządzany
sudo nmcli dev set wlan0 managed yes

# 8. Aktualizacja pliku service dla aplikacji
echo "Aktualizacja konfiguracji aplikacji..."
sudo tee /etc/systemd/system/todo-app.service > /dev/null <<EOF
[Unit]
Description=Todo Kiosk App
After=network.target NetworkManager.service
Wants=NetworkManager.service

[Service]
Type=simple
User=pi
WorkingDirectory=/home/pi/todo
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
Environment="NODE_ENV=production"
ExecStartPre=/bin/sleep 10
ExecStart=/usr/bin/node backend/server-nm.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# 9. Uprawnienia dla użytkownika pi do zarządzania NetworkManager
echo "Konfiguracja uprawnień..."
sudo tee /etc/polkit-1/localauthority/50-local.d/10-pi-network.pkla > /dev/null <<EOF
[Allow pi to manage network]
Identity=unix-user:pi
Action=org.freedesktop.NetworkManager.*
ResultAny=yes
ResultInactive=yes
ResultActive=yes
EOF

# 10. Restart aplikacji
echo "Restartowanie aplikacji..."
sudo systemctl daemon-reload
sudo systemctl restart todo-app

echo ""
echo "=== Konfiguracja zakończona! ==="
echo ""
echo "Aplikacja używa teraz NetworkManager do zarządzania WiFi."
echo "Jest to bardziej stabilne rozwiązanie niż hostapd+dnsmasq."
echo ""
echo "Zalety:"
echo "- Automatyczne zarządzanie konfliktami"
echo "- Lepsze wsparcie dla przełączania AP/Client"
echo "- Wbudowane zarządzanie DHCP"
echo "- Mniej problemów z uprawnieniami"
echo ""
echo "Sprawdź status: sudo systemctl status todo-app"
echo "Logi: sudo journalctl -u todo-app -f"
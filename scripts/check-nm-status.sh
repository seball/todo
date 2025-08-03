#!/bin/bash
# Sprawdza status NetworkManager i konfiguracji WiFi

echo "=== Status NetworkManager ==="
echo ""

# 1. Czy NetworkManager działa
echo "1. NetworkManager service:"
if systemctl is-active --quiet NetworkManager; then
    echo "   ✓ NetworkManager działa"
else
    echo "   ✗ NetworkManager NIE działa!"
    echo "   Uruchom: sudo systemctl start NetworkManager"
fi
echo ""

# 2. Czy nmcli jest dostępny
echo "2. nmcli tool:"
if command -v nmcli &> /dev/null; then
    echo "   ✓ nmcli zainstalowany"
    nmcli -v
else
    echo "   ✗ nmcli nie znaleziony!"
    echo "   Zainstaluj: sudo apt install network-manager"
fi
echo ""

# 3. Status interfejsów
echo "3. Interfejsy sieciowe:"
nmcli device status
echo ""

# 4. Aktywne połączenia
echo "4. Aktywne połączenia:"
nmcli connection show --active
echo ""

# 5. Czy jest aktywny AP
echo "5. Access Point status:"
if nmcli connection show --active | grep -q "TodoAP"; then
    echo "   ✓ Access Point aktywny (TodoAP)"
    echo "   SSID: $(nmcli -t -f 802-11-wireless.ssid con show TodoAP | cut -d: -f2)"
    echo "   IP: 192.168.100.1"
else
    echo "   ✗ Access Point nieaktywny"
fi
echo ""

# 6. WiFi scan
echo "6. Dostępne sieci WiFi:"
sudo nmcli dev wifi list | head -10
echo ""

# 7. Backend status
echo "7. Backend aplikacji:"
if systemctl is-active --quiet todo-app || systemctl is-active --quiet wifi-kiosk-backend; then
    echo "   ✓ Backend działa"
    if curl -s http://localhost/api/status &>/dev/null; then
        echo "   ✓ API odpowiada"
        echo "   Status: $(curl -s http://localhost/api/status | grep -o '"mode":"[^"]*"' | cut -d'"' -f4)"
    else
        echo "   ✗ API nie odpowiada"
    fi
else
    echo "   ✗ Backend nie działa"
fi
echo ""

# 8. Konfliktujące usługi
echo "8. Konfliktujące usługi (powinny być wyłączone):"
for service in hostapd dnsmasq wpa_supplicant; do
    if systemctl is-active --quiet $service; then
        echo "   ⚠ $service DZIAŁA (może powodować konflikty!)"
    else
        echo "   ✓ $service wyłączony"
    fi
done
echo ""

echo "=== Przydatne komendy ==="
echo "Włącz AP:         sudo nmcli con up TodoAP"
echo "Wyłącz AP:        sudo nmcli con down TodoAP"
echo "Lista połączeń:   nmcli con show"
echo "Logi aplikacji:   sudo journalctl -u todo-app -f"
echo "Restart NM:       sudo systemctl restart NetworkManager"
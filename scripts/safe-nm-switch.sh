#!/bin/bash
# Bezpieczne przejście na NetworkManager przez WiFi SSH

echo "=== Bezpieczne przejście na NetworkManager ==="
echo "UWAGA: Łączysz się przez WiFi - będziemy ostrożni!"
echo ""

# 1. Zapisz obecne dane WiFi
echo "1. Zapisuję dane obecnego połączenia WiFi..."
CURRENT_SSID=$(iwgetid -r)
echo "   Obecna sieć: $CURRENT_SSID"

# 2. Wyciągnij hasło z wpa_supplicant
echo "2. Szukam hasła w konfiguracji..."
WPA_CONF="/etc/wpa_supplicant/wpa_supplicant.conf"
if [ -f "$WPA_CONF" ]; then
    # Znajdź hasło dla obecnej sieci
    CURRENT_PSK=$(sudo grep -A 5 "ssid=\"$CURRENT_SSID\"" $WPA_CONF | grep "psk=" | cut -d'"' -f2 | head -1)
    if [ ! -z "$CURRENT_PSK" ]; then
        echo "   Hasło znalezione"
    else
        echo "   UWAGA: Nie znaleziono hasła!"
        echo -n "   Podaj hasło do sieci $CURRENT_SSID: "
        read -s CURRENT_PSK
        echo ""
    fi
fi

# 3. Przygotuj NetworkManager BEZ zatrzymywania dhcpcd
echo "3. Konfiguruję NetworkManager..."

# Upewnij się że NM nie będzie zarządzał połączeniem natychmiast
sudo tee /etc/NetworkManager/NetworkManager.conf > /dev/null <<EOF
[main]
plugins=keyfile
dhcp=internal

[device]
wifi.backend=wpa_supplicant

[keyfile]
unmanaged-devices=interface-name:wlan0

[logging]
level=WARN
EOF

# 4. Uruchom NetworkManager
echo "4. Uruchamiam NetworkManager (wlan0 pozostaje unmanaged)..."
sudo systemctl enable NetworkManager
sudo systemctl start NetworkManager
sleep 3

# 5. Dodaj połączenie WiFi do NetworkManager
echo "5. Dodaję obecne połączenie WiFi do NetworkManager..."
sudo nmcli con add type wifi con-name "$CURRENT_SSID" ifname wlan0 ssid "$CURRENT_SSID"
sudo nmcli con modify "$CURRENT_SSID" wifi-sec.key-mgmt wpa-psk
sudo nmcli con modify "$CURRENT_SSID" wifi-sec.psk "$CURRENT_PSK"
sudo nmcli con modify "$CURRENT_SSID" connection.autoconnect yes
sudo nmcli con modify "$CURRENT_SSID" connection.autoconnect-priority 100

# 6. Dodaj też konfigurację AP
echo "6. Dodaję konfigurację Access Point..."
sudo nmcli con add type wifi ifname wlan0 con-name TodoAP autoconnect no ssid TodoNetwork
sudo nmcli con modify TodoAP 802-11-wireless.mode ap
sudo nmcli con modify TodoAP 802-11-wireless.band bg
sudo nmcli con modify TodoAP ipv4.method shared
sudo nmcli con modify TodoAP ipv4.addresses 192.168.100.1/24
sudo nmcli con modify TodoAP wifi-sec.key-mgmt wpa-psk
sudo nmcli con modify TodoAP wifi-sec.psk "todo12345678"

# 7. Teraz przełącz zarządzanie
echo "7. Przełączam zarządzanie wlan0 na NetworkManager..."
echo ""
echo "UWAGA: Za 5 sekund nastąpi przełączenie!"
echo "Jeśli stracisz połączenie:"
echo "- Poczekaj 30 sekund"
echo "- Spróbuj połączyć się ponownie"
echo "- Lub szukaj AP: TodoNetwork (hasło: todo12345678)"
echo ""
echo "Przełączenie za: 5..."
sleep 1
echo "4..."
sleep 1
echo "3..."
sleep 1
echo "2..."
sleep 1
echo "1..."
sleep 1

# Usuń unmanaged i przełącz
sudo sed -i '/unmanaged-devices/d' /etc/NetworkManager/NetworkManager.conf
sudo systemctl stop dhcpcd
sudo systemctl disable dhcpcd
sudo nmcli dev set wlan0 managed yes
sudo nmcli con up "$CURRENT_SSID"

echo ""
echo "=== Przełączenie zakończone ==="
echo "Jeśli nadal widzisz ten komunikat - sukces!"
#!/bin/bash
# Odświeżenie kiosku przez SSH - bezpośrednie polecenie

echo "=== Odświeżanie kiosku przez SSH ==="

# Metoda 1: Bezpośrednie wywołanie z sudo
echo "Próba 1: Odświeżenie strony (Ctrl+R)..."
if sudo DISPLAY=:0 XAUTHORITY=/home/tomak/.Xauthority xdotool search --class chromium windowfocus key ctrl+r 2>/dev/null; then
    echo "✓ Udało się!"
    exit 0
fi

# Metoda 2: Restart serwisu (pewniejsze)
echo "Próba 2: Restart serwisu GUI..."
if sudo systemctl restart wifi-kiosk-gui; then
    echo "✓ Serwis zrestartowany"
    exit 0
fi

# Metoda 3: Zabicie i restart Chromium
echo "Próba 3: Restart Chromium..."
sudo pkill chromium
sleep 2
sudo -u tomak DISPLAY=:0 /home/tomak/wifi-kiosk/scripts/start-kiosk.sh &
echo "✓ Chromium uruchomiony ponownie"
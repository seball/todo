#!/bin/bash
# Skrypt instalacyjny dla Raspberry Pi OS Lite

set -e

echo "=== Instalacja WiFi Kiosk na Raspberry Pi OS Lite ==="
echo ""

# Sprawdź i utwórz swap jeśli mało RAM
TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
if [ $TOTAL_MEM -lt 1024 ]; then
    echo "Wykryto mało RAM ($TOTAL_MEM MB), tworzę swap..."
    if ! swapon --show | grep -q swapfile; then
        sudo fallocate -l 1G /swapfile
        sudo chmod 600 /swapfile
        sudo mkswap /swapfile
        sudo swapon /swapfile
        if ! grep -q "/swapfile" /etc/fstab; then
            echo "/swapfile none swap sw 0 0" | sudo tee -a /etc/fstab
        fi
        echo "Swap 1GB utworzony!"
    fi
fi

# Sprawdź czy to jest Lite (brak środowiska graficznego)
if pgrep -x "lxsession" > /dev/null || pgrep -x "gnome-session" > /dev/null; then
    echo "Wykryto pełne środowisko graficzne. Użyj ./scripts/install.sh"
    exit 1
fi

echo "Wykryto Raspberry Pi OS Lite - instaluję GUI i aplikację..."
echo ""

# Aktualizuj system
echo "1/8 Aktualizacja systemu..."
sudo apt update && sudo apt upgrade -y

# Zainstaluj minimalne środowisko graficzne
echo "2/8 Instalacja minimalnego X11..."
sudo apt install -y --no-install-recommends \
    xserver-xorg \
    x11-xserver-utils \
    xinit \
    openbox

echo "Instalacja przeglądarki i narzędzi..."
# Sprawdź która wersja Chromium jest dostępna
if apt-cache show chromium-browser >/dev/null 2>&1; then
    echo "Instaluję chromium-browser..."
    sudo apt install -y --no-install-recommends chromium-browser
elif apt-cache show chromium >/dev/null 2>&1; then
    echo "Instaluję chromium..."
    sudo apt install -y --no-install-recommends chromium
else
    echo "BŁĄD: Nie znaleziono pakietu Chromium!"
    echo "Dostępne przeglądarki:"
    apt-cache search chromium
    exit 1
fi

sudo apt install -y --no-install-recommends unclutter

# Zainstaluj Git i podstawowe narzędzia
echo "3/8 Instalacja podstawowych narzędzi..."
sudo apt install -y git unzip curl

# Zainstaluj najnowszy Node.js przez NodeSource
echo "4/8 Instalacja najnowszego Node.js..."
# Sprawdź czy NodeSource repo już dodane
if ! grep -q "nodesource" /etc/apt/sources.list.d/* 2>/dev/null; then
    echo "Dodaję repozytorium NodeSource..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
fi

sudo apt install -y nodejs

# Sprawdź wersje
echo "Zainstalowane wersje:"
node --version
npm --version

# Zainstaluj pakiety WiFi
echo "5/8 Instalacja pakietów WiFi..."
sudo apt install -y hostapd dnsmasq wireless-tools wpasupplicant

# Zatrzymaj usługi które będą zarządzane przez aplikację
sudo systemctl stop hostapd dnsmasq 2>/dev/null || true
sudo systemctl disable hostapd dnsmasq 2>/dev/null || true

# Instalacja zależności backend
echo "6/8 Instalacja zależności Node.js..."
cd backend
npm install express body-parser
cd ..

# Budowanie frontendu React
echo "7/8 Budowanie frontendu React..."
cd frontend
npm install

# Dodaj web-vitals jeśli brakuje
if ! grep -q "web-vitals" package.json; then
    npm install web-vitals --save
fi

# Build z ograniczeniem pamięci
export NODE_OPTIONS="--max-old-space-size=512"
export GENERATE_SOURCEMAP=false
npm run build
unset NODE_OPTIONS
cd ..

# Konfiguracja GUI dla Lite
echo "8/8 Konfiguracja autostartu GUI..."

# Sprawdź i zainstaluj bash jeśli potrzebny
if [ ! -f /bin/bash ]; then
    echo "Instaluję bash..."
    sudo apt install -y bash
fi

# Upewnij się że user używa bash jako login shell
CURRENT_SHELL=$(getent passwd $USER | cut -d: -f7)
if [ "$CURRENT_SHELL" != "/bin/bash" ]; then
    echo "Zmieniam shell na bash dla usera $USER..."
    sudo chsh -s /bin/bash $USER
    echo "UWAGA: Shell zmieniony na bash. Po reboocie będzie aktywny."
fi

# Włącz automatyczne logowanie do konsoli
sudo raspi-config nonint do_boot_behaviour B2

# Skonfiguruj automatyczny start X11
if ! grep -q "exec startx" ~/.bashrc; then
    echo "" >> ~/.bashrc
    echo "# Automatyczny start X11 dla WiFi Kiosk" >> ~/.bashrc
    echo 'if [ -z "$DISPLAY" ] && [ "$XDG_VTNR" = 1 ]; then' >> ~/.bashrc
    echo '  exec startx' >> ~/.bashrc
    echo 'fi' >> ~/.bashrc
fi

# Utwórz .xinitrc (kompatybilny z sh)
cat > ~/.xinitrc << 'EOF'
#!/bin/sh

# Wyłącz wygaszacz ekranu
xset s off
xset -dpms
xset s noblank

# Ukryj kursor myszy
unclutter -idle 0.5 -root &

# Uruchom window manager w tle
openbox &

# Czekaj na backend (bez bash-specific syntax)
echo "Czekam na backend..."
while ! curl -s http://localhost >/dev/null 2>&1; do
    sleep 2
done

# Wykryj dostępną przeglądarkę i uruchom
if command -v chromium-browser >/dev/null 2>&1; then
    BROWSER="chromium-browser"
elif command -v chromium >/dev/null 2>&1; then
    BROWSER="chromium"
elif command -v firefox-esr >/dev/null 2>&1; then
    BROWSER="firefox-esr"
else
    echo "Brak przeglądarki!" > /tmp/kiosk-error.log
    exit 1
fi

# Uruchom aplikację kiosk
exec $BROWSER --noerrdialogs --kiosk --incognito http://localhost \
  --disable-translate --no-first-run --fast --fast-start \
  --disable-infobars --disable-features=TranslateUI \
  --disk-cache-dir=/dev/null --password-store=basic \
  --disable-pinch --overscroll-history-navigation=disabled \
  --disable-features=TouchpadOverscrollHistoryNavigation
EOF

chmod +x ~/.xinitrc

echo ""
echo "=== Instalacja na Lite zakończona! ==="
echo ""
echo "Uruchom teraz:"
echo "  ./scripts/configure-services.sh"
echo "  sudo reboot"
echo ""
echo "Po restarcie GUI uruchomi się automatycznie w trybie kiosk."
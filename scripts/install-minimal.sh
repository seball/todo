#!/bin/bash
# Skrypt ultra-minimalnej instalacji dla Raspberry Pi OS Lite
# Instaluje tylko niezbędne pakiety X11

set -e

echo "=== Ultra-minimalna instalacja WiFi Kiosk ==="
echo "Ta instalacja zajmie najmniej miejsca na dysku"
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

# Sprawdź czy to jest Lite
if pgrep -x "lxsession" > /dev/null || pgrep -x "gnome-session" > /dev/null; then
    echo "Wykryto pełne środowisko graficzne. Użyj ./scripts/install.sh"
    exit 1
fi

echo "Instaluję tylko niezbędne pakiety..."
echo ""

# Aktualizuj system
echo "1/10 Aktualizacja systemu..."
sudo apt update

# Minimalne X11 - tylko to co potrzebne
echo "2/10 Instalacja ultra-minimalnego X11..."
sudo apt install -y --no-install-recommends \
    xserver-xorg-core \
    xserver-xorg-input-libinput \
    xserver-xorg-video-fbdev \
    x11-xserver-utils \
    xinit \
    openbox

echo "3/10 Instalacja przeglądarki..."
# Wykryj dostępną wersję Chromium
if apt-cache show chromium-browser >/dev/null 2>&1; then
    echo "Instaluję chromium-browser..."
    sudo apt install -y --no-install-recommends chromium-browser fonts-liberation
elif apt-cache show chromium >/dev/null 2>&1; then
    echo "Instaluję chromium..."
    sudo apt install -y --no-install-recommends chromium fonts-liberation
else
    echo "UWAGA: Nie znaleziono Chromium, próbuję Firefox ESR..."
    sudo apt install -y --no-install-recommends firefox-esr
fi

# Podstawowe narzędzia
echo "4/10 Instalacja narzędzi..."
sudo apt install -y --no-install-recommends \
    unclutter \
    curl

# Zależności aplikacji  
echo "5/6 Instalacja Git..."
sudo apt install -y git

# Zainstaluj najnowszy Node.js
echo "6/7 Instalacja najnowszego Node.js..."
if ! grep -q "nodesource" /etc/apt/sources.list.d/* 2>/dev/null; then
    echo "Dodaję repozytorium NodeSource..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
fi

sudo apt install -y nodejs

echo "Zainstalowane wersje:"
node --version
npm --version

# NetworkManager
echo "7/8 Instalacja NetworkManager..."
sudo apt install -y --no-install-recommends \
    network-manager \
    wireless-tools

# Instalacja zależności backend
echo "8/9 Instalacja zależności backend..."
cd backend
npm install express body-parser
cd ..

# Budowanie frontendu React
echo "9/10 Budowanie frontendu React..."
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

# Konfiguracja GUI
echo "10/10 Konfiguracja autostartu..."

# Sprawdź bash
if [ ! -f /bin/bash ]; then
    sudo apt install -y bash
fi

# Upewnij się że user używa bash
CURRENT_SHELL=$(getent passwd $USER | cut -d: -f7)
if [ "$CURRENT_SHELL" != "/bin/bash" ]; then
    echo "Zmieniam shell na bash..."
    sudo chsh -s /bin/bash $USER
fi

# Autologowanie
sudo raspi-config nonint do_boot_behaviour B2

# Auto-start X11
if ! grep -q "exec startx" ~/.bashrc; then
    echo "" >> ~/.bashrc
    echo "# Auto-start X11 dla WiFi Kiosk" >> ~/.bashrc
    echo 'if [ -z "$DISPLAY" ] && [ "$XDG_VTNR" = 1 ]; then' >> ~/.bashrc
    echo '  exec startx' >> ~/.bashrc
    echo 'fi' >> ~/.bashrc
fi

# Ultra-minimalny .xinitrc (kompatybilny z sh)
cat > ~/.xinitrc << 'EOF'
#!/bin/sh

# Disable screen blanking
xset s off -dpms

# Hide cursor
unclutter -idle 0.5 -root &

# Start minimal window manager
openbox &

# Wait for backend
while ! curl -s http://localhost >/dev/null 2>&1; do sleep 2; done

# Start kiosk
exec chromium-browser \
  --kiosk \
  --no-sandbox \
  --disable-dev-shm-usage \
  --disable-gpu \
  --disable-features=VizDisplayCompositor \
  --incognito \
  --noerrdialogs \
  --disable-translate \
  --no-first-run \
  --disable-infobars \
  --disable-features=TranslateUI \
  --disk-cache-dir=/dev/null \
  --disable-background-timer-throttling \
  --disable-renderer-backgrounding \
  http://localhost
EOF

chmod +x ~/.xinitrc

echo ""
echo "=== Ultra-minimalna instalacja zakończona! ==="
echo ""
echo "Zainstalowane pakiety używają minimum miejsca na dysku."
echo "Uruchom teraz:"
echo "  ./scripts/configure-services.sh"
echo "  sudo reboot"
echo ""
echo "Oszczędności miejsca vs standardowa instalacja: ~200-300MB"
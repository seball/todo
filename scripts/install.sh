#!/bin/bash
set -e
echo "Instalacja zależności dla WiFi Kiosk..."

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

# Aktualizacja systemu
sudo apt update

# Instalacja podstawowych pakietów
sudo apt install -y git unzip curl

# Zainstaluj najnowszy Node.js przez NodeSource
echo "Instalacja najnowszego Node.js..."
if ! grep -q "nodesource" /etc/apt/sources.list.d/* 2>/dev/null; then
    echo "Dodaję repozytorium NodeSource..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
fi

sudo apt install -y nodejs

# Sprawdź wersje
echo "Zainstalowane wersje:"
node --version
npm --version

# Instalacja pakietów dla hotspota
sudo apt install -y hostapd dnsmasq wireless-tools wpasupplicant

# Zatrzymaj usługi które będą zarządzane przez aplikację
sudo systemctl stop hostapd 2>/dev/null || true
sudo systemctl stop dnsmasq 2>/dev/null || true
sudo systemctl disable hostapd 2>/dev/null || true
sudo systemctl disable dnsmasq 2>/dev/null || true

# Instalacja zależności backend
cd backend
npm install express body-parser

# Budowanie frontendu React
cd ../frontend
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

echo "Instalacja zakończona!"

#!/bin/bash
set -e
echo "Instalacja zależności dla WiFi Kiosk..."

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
npm run build

echo "Instalacja zakończona!"

#!/bin/bash
# Uruchomienie serwera WiFi Kiosk

# Przejdź do katalogu backend
cd "$(dirname "$0")/../backend"

# Sprawdź czy frontend jest zbudowany
if [ ! -d "../frontend/build" ]; then
    echo "Frontend nie jest zbudowany. Uruchamiam build..."
    cd ../frontend
    npm run build
    cd ../backend
fi

# Uruchom serwer z uprawnieniami root (wymagane dla konfiguracji WiFi)
echo "Uruchamianie serwera WiFi Kiosk..."
sudo node server.js

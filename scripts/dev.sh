#!/bin/bash
# Skrypt do uruchamiania w trybie development (bez budowania frontendu)

echo "=== Tryb development WiFi Kiosk ==="
echo ""
echo "UWAGA: Ten skrypt zakłada, że frontend jest już zbudowany!"
echo "Jeśli nie, uruchom najpierw: cd frontend && npm run build"
echo ""

# Przejdź do katalogu backend
cd "$(dirname "$0")/../backend"

# Uruchom serwer
echo "Uruchamianie serwera (tryb development)..."
sudo node server.js
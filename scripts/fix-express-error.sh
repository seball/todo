#!/bin/bash
# Skrypt naprawiający błąd Express/path-to-regexp na Raspberry Pi

set -e

echo "=== Naprawianie błędu Express ===="
echo ""

# Sprawdź czy jesteśmy w katalogu projektu
if [ ! -f "backend/server.js" ]; then
    echo "BŁĄD: Uruchom skrypt z głównego katalogu projektu!"
    exit 1
fi

echo "1. Czyszczenie starych zależności..."
cd backend
rm -rf node_modules package-lock.json

# Sprawdź czy istnieje package.json
if [ ! -f "package.json" ]; then
    echo "2. Tworzenie package.json..."
    cat > package.json << EOF
{
  "name": "wifi-kiosk-backend",
  "version": "1.0.0",
  "description": "WiFi Kiosk Backend Server",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "body-parser": "^1.20.2"
  }
}
EOF
else
    echo "2. package.json już istnieje"
fi

echo "3. Instalacja prawidłowych wersji Express..."
npm install express@4.18.2 body-parser@1.20.2

echo "4. Test lokalny..."
# Test czy serwer uruchamia się poprawnie
timeout 5s node server.js > /dev/null 2>&1 || true

if [ $? -eq 124 ]; then
    echo "✓ Serwer uruchamia się poprawnie (timeout po 5s to normalne)"
else
    echo "✗ Problem z uruchomieniem serwera"
fi

cd ..

echo ""
echo "5. Restart serwisu..."
sudo systemctl restart wifi-kiosk-backend

echo "6. Sprawdzanie statusu..."
sleep 2
if sudo systemctl is-active --quiet wifi-kiosk-backend; then
    echo "✓ Serwis działa poprawnie!"
    echo ""
    echo "Sprawdź logi: sudo journalctl -u wifi-kiosk-backend -f"
else
    echo "✗ Serwis nie działa!"
    echo "Sprawdź błędy: sudo journalctl -u wifi-kiosk-backend -n 50"
fi

echo ""
echo "=== Gotowe! ==="
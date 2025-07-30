#!/bin/bash
# Szybki redeploy przez SSH - aktualizuje kod i restartuje services

set -e

echo "=== Szybki redeploy WiFi Kiosk ==="
echo ""

# Sprawdź czy jesteśmy w katalogu projektu
if [ ! -f "frontend/package.json" ] || [ ! -f "backend/server.js" ]; then
    echo "BŁĄD: Uruchom skrypt z głównego katalogu projektu!"
    exit 1
fi

echo "1. Aktualizacja kodu z git..."
git pull origin main

echo "2. Aktualizacja zależności backend..."
cd backend
if [ -f "package.json" ]; then
    npm install --production
fi
cd ..

echo "3. Rebuild frontendu..."
cd frontend

# Sprawdź czy jest build
if [ ! -d "build" ]; then
    echo "Brak build/ - instaluję zależności..."
    npm install
fi

# Dodaj web-vitals jeśli brakuje
if ! grep -q "web-vitals" package.json; then
    npm install web-vitals --save
fi

# Build z ograniczeniem pamięci
export NODE_OPTIONS="--max-old-space-size=512"
export GENERATE_SOURCEMAP=false
echo "Budowanie React app..."
npm run build
unset NODE_OPTIONS

cd ..

echo "4. Restart services..."
sudo systemctl restart wifi-kiosk-backend

# Sprawdź czy GUI service istnieje i jest włączone
if systemctl is-enabled wifi-kiosk-gui >/dev/null 2>&1; then
    sudo systemctl restart wifi-kiosk-gui
    echo "GUI service zrestartowane"
fi

echo "5. Sprawdzanie statusu..."
sleep 3

if sudo systemctl is-active --quiet wifi-kiosk-backend; then
    echo "✓ Backend działa"
    
    # Test API
    if curl -s http://localhost/api/status >/dev/null; then
        echo "✓ API odpowiada"
    else
        echo "⚠ API nie odpowiada"
    fi
else
    echo "✗ Backend nie działa!"
    echo "Sprawdź logi: sudo journalctl -u wifi-kiosk-backend -n 20"
fi

echo ""
echo "=== Redeploy zakończony! ==="
echo ""
echo "Aplikacja dostępna na: http://localhost"
echo "Sprawdź logi: sudo journalctl -u wifi-kiosk-backend -f"
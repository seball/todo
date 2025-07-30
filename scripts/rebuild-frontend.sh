#!/bin/bash
# Skrypt do przebudowania frontendu

set -e

echo "=== Rebuild Frontend ==="
echo ""

# Sprawdź czy jesteśmy w odpowiednim katalogu
if [ ! -d "frontend" ]; then
    echo "BŁĄD: Nie znaleziono katalogu frontend!"
    echo "Uruchom skrypt z głównego katalogu projektu."
    exit 1
fi

cd frontend

# Sprawdź czy node_modules istnieje
if [ ! -d "node_modules" ]; then
    echo "Instalowanie zależności frontend..."
    npm install
fi

# Usuń stary build
echo "Usuwanie starego buildu..."
rm -rf build

# Buduj nową wersję
echo "Budowanie frontendu..."
npm run build

# Sprawdź czy build się udał
if [ ! -d "build" ]; then
    echo "BŁĄD: Budowanie nie powiodło się!"
    exit 1
fi

echo ""
echo "=== Frontend zbudowany pomyślnie! ==="
echo ""
echo "Możesz teraz:"
echo "1. Zrestartować backend: sudo systemctl restart wifi-kiosk-backend"
echo "2. Lub uruchomić w trybie dev: ./scripts/dev.sh"
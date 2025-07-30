#!/bin/bash
# Skrypt do aktualizacji aplikacji WiFi Kiosk

set -e

echo "=== Aktualizacja WiFi Kiosk ==="
echo ""

# Sprawdź czy jesteśmy w katalogu projektu
if [ ! -f "backend/server.js" ]; then
    echo "BŁĄD: Uruchom skrypt z głównego katalogu projektu!"
    exit 1
fi

# Zatrzymaj services
echo "Zatrzymywanie services..."
sudo systemctl stop wifi-kiosk-backend || true
sudo systemctl stop wifi-kiosk-gui || true

# Pobierz najnowsze zmiany
echo "Pobieranie najnowszych zmian z git..."
git pull

# Aktualizuj zależności backend
echo "Aktualizacja zależności backend..."
cd backend
npm install
cd ..

# Aktualizuj i przebuduj frontend
echo "Aktualizacja i budowanie frontend..."
cd frontend

# Usuń stary build
rm -rf build

# Zainstaluj/aktualizuj zależności
npm install

# Buduj produkcyjną wersję
echo "Budowanie produkcyjnej wersji frontendu..."
npm run build

# Sprawdź czy build się udał
if [ ! -d "build" ]; then
    echo "BŁĄD: Budowanie frontendu nie powiodło się!"
    exit 1
fi

cd ..

# Sprawdź czy trzeba zaktualizować uprawnienia
echo "Aktualizacja uprawnień..."
chmod +x scripts/*.sh

# Restart services
echo "Restartowanie services..."
sudo systemctl start wifi-kiosk-backend
sleep 2
sudo systemctl start wifi-kiosk-gui || true

# Sprawdź status
echo ""
echo "=== Status po aktualizacji ==="
sudo systemctl status wifi-kiosk-backend --no-pager

echo ""
echo "=== Aktualizacja zakończona! ==="
echo ""
echo "Frontend został przebudowany i services zostały zrestartowane."
echo "Jeśli były zmiany w plikach service, uruchom:"
echo "./scripts/setup-services.sh"
echo ""
echo "Logi możesz sprawdzić za pomocą:"
echo "sudo journalctl -u wifi-kiosk-backend -f"
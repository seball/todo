#!/bin/bash
# Skrypt do naprawy problemów z pamięcią podczas budowania React na Raspberry Pi

set -e

echo "=== Naprawianie problemów z pamięcią dla React build ==="
echo ""

# Sprawdź czy jesteśmy w katalogu projektu
if [ ! -f "frontend/package.json" ]; then
    echo "BŁĄD: Uruchom skrypt z głównego katalogu projektu!"
    exit 1
fi

# Opcja 1: Dodaj swap jeśli nie istnieje
if ! swapon --show | grep -q swapfile; then
    echo "1. Tworzenie pliku swap (1GB)..."
    sudo fallocate -l 1G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    
    # Dodaj do fstab dla trwałości
    if ! grep -q "/swapfile" /etc/fstab; then
        echo "/swapfile none swap sw 0 0" | sudo tee -a /etc/fstab
    fi
    echo "Swap utworzony!"
else
    echo "Swap już istnieje, pomijam..."
fi

# Opcja 2: Wyczyść cache
echo ""
echo "2. Czyszczenie cache..."
cd frontend
rm -rf node_modules/.cache
rm -rf build

# Opcja 3: Instaluj brakujące zależności
echo ""
echo "3. Instalacja brakujących zależności..."
if ! grep -q "web-vitals" package.json; then
    npm install web-vitals --save
fi

# Opcja 4: Buduj z ograniczeniami pamięci
echo ""
echo "4. Budowanie z ograniczeniami pamięci..."
export NODE_OPTIONS="--max-old-space-size=512"
export GENERATE_SOURCEMAP=false

# Próba budowania
echo ""
echo "Próbuję zbudować frontend..."
npm run build

# Sprawdź rezultat
if [ -d "build" ] && [ -f "build/index.html" ]; then
    echo ""
    echo "=== Budowanie zakończone pomyślnie! ==="
    echo "Frontend zbudowany w: $(pwd)/build"
else
    echo ""
    echo "=== Budowanie nie powiodło się ==="
    echo ""
    echo "Alternatywne rozwiązanie:"
    echo "1. Zbuduj frontend na PC z większą ilością RAM:"
    echo "   - Na PC: cd frontend && npm run build"
    echo "   - Skopiuj folder 'build' na Raspberry Pi"
    echo ""
    echo "2. Lub usuń niepotrzebne importy:"
    echo "   sed -i '/reportWebVitals/d' src/index.js"
    echo "   sed -i '/web-vitals/d' src/index.js"
    echo "   npm run build"
fi

cd ..
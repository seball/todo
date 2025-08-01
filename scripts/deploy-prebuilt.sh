#!/bin/bash
# Deploy z prebuild - buduj lokalnie, wyślij na Pi

set -e

echo "=== Deploy z lokalnym buildem ==="

# Sprawdź parametry
if [ -z "$1" ]; then
    echo "Użycie: $0 <adres-ip-raspberry>"
    echo "Przykład: $0 192.168.1.100"
    exit 1
fi

PI_HOST="pi@$1"
REMOTE_DIR="/home/pi/wifi-kiosk"

# 1. Build lokalnie
echo "1. Budowanie frontendu lokalnie..."
cd frontend
npm run build
cd ..

# 2. Tworzenie archiwum
echo "2. Pakowanie build..."
tar -czf frontend-build.tar.gz -C frontend/build .

# 3. Wysyłanie na Pi
echo "3. Wysyłanie na Raspberry Pi..."
scp frontend-build.tar.gz $PI_HOST:/tmp/

# 4. Rozpakowanie na Pi
echo "4. Instalacja na Pi..."
ssh $PI_HOST << 'EOF'
    cd /home/pi/wifi-kiosk
    rm -rf frontend/build
    mkdir -p frontend/build
    tar -xzf /tmp/frontend-build.tar.gz -C frontend/build
    rm /tmp/frontend-build.tar.gz
    
    # Restart serwisów
    sudo systemctl restart wifi-kiosk-backend
    if systemctl is-enabled wifi-kiosk-gui >/dev/null 2>&1; then
        sudo systemctl restart wifi-kiosk-gui
    fi
    
    echo "✓ Deploy zakończony!"
EOF

# 5. Cleanup
rm -f frontend-build.tar.gz

echo "=== Gotowe! ==="
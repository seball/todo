#!/bin/bash
# Szybki redeploy przez SSH - aktualizuje kod i restartuje services

set -e

# Parsuj argumenty
SKIP_BUILD=false
SKIP_NPM=false
BACKEND_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --skip-npm)
            SKIP_NPM=true
            shift
            ;;
        --backend-only)
            BACKEND_ONLY=true
            shift
            ;;
        --help)
            echo "Użycie: $0 [opcje]"
            echo "Opcje:"
            echo "  --skip-build    Pomiń budowanie frontendu (użyj gdy tylko backend się zmienił)"
            echo "  --skip-npm      Pomiń instalację pakietów npm"
            echo "  --backend-only  Tylko restart backendu (najszybsze)"
            echo ""
            echo "Przykłady:"
            echo "  $0                    # Pełny deploy"
            echo "  $0 --skip-build       # Bez budowania frontendu"
            echo "  $0 --backend-only     # Tylko restart backendu"
            exit 0
            ;;
        *)
            echo "Nieznana opcja: $1"
            exit 1
            ;;
    esac
done

echo "=== Szybki redeploy WiFi Kiosk ==="
if [ "$SKIP_BUILD" = true ]; then
    echo "    (pomijam budowanie frontendu)"
fi
if [ "$SKIP_NPM" = true ]; then
    echo "    (pomijam instalację pakietów)"
fi
if [ "$BACKEND_ONLY" = true ]; then
    echo "    (tylko restart backendu)"
fi
echo ""

# Sprawdź czy jesteśmy w katalogu projektu
if [ ! -f "frontend/package.json" ] || [ ! -f "backend/server.js" ]; then
    echo "BŁĄD: Uruchom skrypt z głównego katalogu projektu!"
    exit 1
fi

echo "1. Aktualizacja kodu z git..."
git pull origin main

if [ "$BACKEND_ONLY" = false ]; then
    echo "2. Aktualizacja zależności backend..."
    cd backend
    if [ "$SKIP_NPM" = false ] && [ -f "package.json" ]; then
        npm install --production
    else
        echo "   (pomijam npm install)"
    fi
    cd ..

    if [ "$SKIP_BUILD" = false ]; then
        echo "3. Rebuild frontendu..."
        cd frontend

        # Sprawdź czy jest build
        if [ ! -d "build" ]; then
            echo "Brak build/ - instaluję zależności..."
            if [ "$SKIP_NPM" = false ]; then
                npm install
            fi
        fi

        # Dodaj web-vitals jeśli brakuje
        if [ "$SKIP_NPM" = false ] && ! grep -q "web-vitals" package.json; then
            npm install web-vitals --save
        fi

        # Build z ograniczeniem pamięci
        export NODE_OPTIONS="--max-old-space-size=512"
        export GENERATE_SOURCEMAP=false
        echo "Budowanie React app..."
        npm run build
        unset NODE_OPTIONS

        cd ..
    else
        echo "3. Pomijam rebuild frontendu"
    fi
else
    echo "2. Pomijam aktualizację zależności (tylko backend)"
    echo "3. Pomijam rebuild frontendu (tylko backend)"
fi

echo "4. Restart services..."
sudo systemctl restart wifi-kiosk-backend

# Sprawdź czy GUI service istnieje i jest włączone
if systemctl is-enabled wifi-kiosk-gui >/dev/null 2>&1; then
    sudo systemctl restart wifi-kiosk-gui
    echo "GUI service zrestartowane"
else
    # Jeśli nie ma systemd service, spróbuj przeładować Chromium bezpośrednio
    echo "Próba przeładowania przeglądarki..."
    
    # Opcja 1: Wyślij SIGHUP do Chromium (przeładowanie strony)
    if pgrep -x "chromium-browser" > /dev/null || pgrep -x "chromium" > /dev/null; then
        # Znajdź PID Chromium
        CHROMIUM_PID=$(pgrep -x "chromium-browser" || pgrep -x "chromium" | head -1)
        if [ ! -z "$CHROMIUM_PID" ]; then
            # Wyślij Ctrl+R do okna Chromium przez xdotool
            if command -v xdotool >/dev/null 2>&1; then
                export DISPLAY=:0
                xdotool search --onlyvisible --class chromium windowfocus key ctrl+r
                echo "✓ Strona przeładowana (Ctrl+R)"
            else
                echo "⚠ xdotool nie zainstalowany - nie mogę przeładować strony"
                echo "  Zainstaluj: sudo apt-get install xdotool"
            fi
        fi
    fi
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
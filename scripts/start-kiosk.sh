#!/bin/bash
# Skrypt do uruchamiania przeglądarki w trybie kiosk

echo "Uruchamianie trybu kiosk..."

# Sprawdź czy curl jest dostępny
if ! command -v curl >/dev/null 2>&1; then
    echo "BŁĄD: curl nie jest zainstalowany!"
    echo "Zainstaluj curl: sudo apt install curl"
    exit 1
fi

# Czekaj na backend
echo "Czekam na backend na localhost:80..."
TIMEOUT=60
COUNTER=0
while ! curl -s http://localhost >/dev/null 2>&1; do
    echo "Backend nie gotowy, czekam... ($COUNTER/$TIMEOUT)"
    sleep 2
    COUNTER=$((COUNTER + 2))
    if [ $COUNTER -ge $TIMEOUT ]; then
        echo "BŁĄD: Backend nie odpowiada po $TIMEOUT sekundach!"
        echo "Sprawdź: sudo systemctl status wifi-kiosk-backend"
        exit 1
    fi
done

echo "Backend gotowy, uruchamiam przeglądarkę..."

# Wykryj dostępną przeglądarkę i uruchom w trybie kiosk
if command -v chromium-browser >/dev/null 2>&1; then
    echo "Używam chromium-browser"
    exec chromium-browser \
        --noerrdialogs \
        --kiosk \
        --incognito \
        --disable-translate \
        --no-first-run \
        --fast \
        --fast-start \
        --disable-infobars \
        --disable-features=TranslateUI \
        --disk-cache-dir=/dev/null \
        --password-store=basic \
        --disable-pinch \
        --overscroll-history-navigation=disabled \
        --disable-features=TouchpadOverscrollHistoryNavigation \
        http://localhost

elif command -v chromium >/dev/null 2>&1; then
    echo "Używam chromium"
    exec chromium \
        --noerrdialogs \
        --kiosk \
        --incognito \
        --disable-translate \
        --no-first-run \
        --fast \
        --fast-start \
        --disable-infobars \
        --disable-features=TranslateUI \
        --disk-cache-dir=/dev/null \
        --password-store=basic \
        --disable-pinch \
        --overscroll-history-navigation=disabled \
        --disable-features=TouchpadOverscrollHistoryNavigation \
        http://localhost

elif command -v firefox-esr >/dev/null 2>&1; then
    echo "Używam Firefox ESR (fallback)"
    # Konfiguracja Firefox dla kiosk mode
    export MOZ_DISABLE_CONTENT_SANDBOX=1
    exec firefox-esr \
        --kiosk \
        --private-window \
        http://localhost

else
    echo "BŁĄD: Nie znaleziono przeglądarki!"
    echo "Zainstaluj chromium-browser, chromium lub firefox-esr"
    exit 1
fi
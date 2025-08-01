#!/bin/bash
# Szybkie odświeżenie przeglądarki kiosk bez restartu

echo "=== Odświeżanie przeglądarki kiosk ==="

# Sprawdź czy xdotool jest zainstalowany
if ! command -v xdotool >/dev/null 2>&1; then
    echo "BŁĄD: xdotool nie jest zainstalowany!"
    echo "Zainstaluj: sudo apt-get install xdotool"
    exit 1
fi

# Ustaw display
export DISPLAY=:0

# Znajdź okno Chromium i odśwież
if xdotool search --onlyvisible --class chromium windowfocus key ctrl+r; then
    echo "✓ Strona przeładowana (Ctrl+R)"
elif xdotool search --onlyvisible --class firefox windowfocus key ctrl+r; then
    echo "✓ Strona przeładowana w Firefox (Ctrl+R)"
else
    echo "✗ Nie znaleziono okna przeglądarki"
    echo "Sprawdź czy kiosk działa: ps aux | grep chromium"
    exit 1
fi

# Opcjonalnie - wyczyść cache (Ctrl+Shift+R)
if [ "$1" = "--hard" ]; then
    echo "Twarde przeładowanie (Ctrl+Shift+R)..."
    xdotool search --onlyvisible --class chromium windowfocus key ctrl+shift+r || \
    xdotool search --onlyvisible --class firefox windowfocus key ctrl+shift+r
    echo "✓ Cache wyczyszczony"
fi

echo "=== Gotowe! ==="
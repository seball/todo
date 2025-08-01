#!/bin/bash
# Szybkie odświeżenie przeglądarki kiosk bez restartu

echo "=== Odświeżanie przeglądarki kiosk ==="

# Sprawdź czy xdotool jest zainstalowany
if ! command -v xdotool >/dev/null 2>&1; then
    echo "BŁĄD: xdotool nie jest zainstalowany!"
    echo "Zainstaluj: sudo apt-get install xdotool"
    exit 1
fi

# Ustaw display i XAUTHORITY
export DISPLAY=:0
export XAUTHORITY=/home/$USER/.Xauthority

# Jeśli uruchomione przez SSH, może być potrzebne sudo
if [ -z "$SSH_TTY" ]; then
    # Lokalne uruchomienie
    XDOTOOL="xdotool"
else
    # Przez SSH - użyj sudo z zachowaniem zmiennych środowiskowych
    XDOTOOL="sudo -E xdotool"
fi

# Znajdź okno Chromium i odśwież
if $XDOTOOL search --onlyvisible --class chromium windowfocus key ctrl+r 2>/dev/null; then
    echo "✓ Strona przeładowana (Ctrl+R)"
elif $XDOTOOL search --onlyvisible --class firefox windowfocus key ctrl+r 2>/dev/null; then
    echo "✓ Strona przeładowana w Firefox (Ctrl+R)"
else
    echo "✗ Nie znaleziono okna przeglądarki lub brak dostępu do X11"
    echo ""
    echo "Jeśli jesteś połączony przez SSH, spróbuj:"
    echo "1. sudo DISPLAY=:0 xdotool search --class chromium windowfocus key ctrl+r"
    echo ""
    echo "Lub zrestartuj cały serwis GUI:"
    echo "2. sudo systemctl restart wifi-kiosk-gui"
    echo ""
    echo "Procesy Chromium:"
    ps aux | grep chromium | grep -v grep | head -3
    exit 1
fi

# Opcjonalnie - wyczyść cache (Ctrl+Shift+R)
if [ "$1" = "--hard" ]; then
    echo "Twarde przeładowanie (Ctrl+Shift+R)..."
    $XDOTOOL search --onlyvisible --class chromium windowfocus key ctrl+shift+r 2>/dev/null || \
    $XDOTOOL search --onlyvisible --class firefox windowfocus key ctrl+shift+r 2>/dev/null
    echo "✓ Cache wyczyszczony"
fi

echo "=== Gotowe! ==="
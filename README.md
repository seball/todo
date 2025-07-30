# WiFi Kiosk dla Raspberry Pi

Aplikacja kiosk umożliwiająca konfigurację WiFi na Raspberry Pi bez klawiatury i myszki. Urządzenie tworzy hotspot WiFi, do którego można połączyć się telefonem i skonfigurować docelową sieć WiFi.

## ⚡ Szybka instalacja

### Raspberry Pi OS Full (z GUI)
```bash
git clone https://github.com/seball/wifi-kiosk.git ~/wifi-kiosk
cd ~/wifi-kiosk
chmod +x scripts/*.sh
./scripts/install.sh
./scripts/configure-services.sh  # Auto-wykrywa usera!
sudo reboot
```

### Raspberry Pi OS Lite (bez GUI)

**Standard (zalecane):**
```bash
git clone https://github.com/seball/wifi-kiosk.git ~/wifi-kiosk
cd ~/wifi-kiosk
chmod +x scripts/*.sh
./scripts/install-lite.sh        # Minimalne X11 + OpenBox
./scripts/configure-services.sh  # Auto-wykrywa usera!
sudo reboot
```

**Ultra-minimalne (oszczędność miejsca):**
```bash
git clone https://github.com/seball/wifi-kiosk.git ~/wifi-kiosk
cd ~/wifi-kiosk
chmod +x scripts/*.sh
./scripts/install-minimal.sh     # Tylko niezbędne pakiety
./scripts/configure-services.sh
sudo reboot
```

## 🌟 Funkcjonalności

- **Automatyczny hotspot WiFi** - Raspberry Pi tworzy własną sieć WiFi z losową nazwą i hasłem
- **QR Code** - Szybkie połączenie z hotspotem przez zeskanowanie kodu QR
- **Skanowanie sieci** - Wyświetla dostępne sieci WiFi z siłą sygnału
- **Interfejs webowy** - Prosta konfiguracja przez przeglądarkę na telefonie
- **Tryb kiosk** - Automatyczne uruchomienie w pełnoekranowym trybie
- **Autostart** - Uruchamia się automatycznie po włączeniu Raspberry Pi

## 📋 Wymagania

- Raspberry Pi z WiFi (testowane na RPi 3B+, 4)
- Raspberry Pi OS (Bullseye lub nowszy) - Lite lub Full
- Połączenie internetowe przez Ethernet (na czas instalacji)
- **Node.js LTS automatycznie instalowany** (NodeSource repo)
- Ekran lub monitor podłączony do Raspberry Pi (dla trybu kiosk)

### 👤 Kompatybilność userów

Aplikacja **automatycznie wykrywa aktualnego usera** i konfiguruje services:

- ✅ **Standardowy user `pi`** - działa out-of-the-box
- ✅ **Niestandardowy user** (np. `admin`, `kiosk`) - automatycznie wykrywany
- ✅ **Nowsze Raspberry Pi OS** - bez domyślnego usera pi
- ⚠️ **Root login** - nie zalecane, ale obsługiwane

**Backend zawsze działa jako `root`** (wymagane do konfiguracji WiFi)
**GUI działa jako aktualny user** (ten który instaluje aplikację)

### 📦 Opcje instalacji

| Opcja | OS | Skrypt | Pakiety | Miejsce | Opis |
|-------|----|---------|---------|---------|----- |
| **Standard** | Full | `install.sh` | LXDE + extras | ~500MB | Pełne środowisko |
| **Lite** | Lite | `install-lite.sh` | X11 + OpenBox | ~200MB | Minimalne GUI |
| **Ultra-minimal** | Lite | `install-minimal.sh` | Core X11 only | ~100MB | Tylko niezbędne |

## 🚀 Instalacja przez SSH

### 1. Połącz się z Raspberry Pi przez SSH

```bash
ssh pi@raspberrypi.local
# lub
ssh pi@<IP_ADRES>
```

### 2. Sklonuj repozytorium

```bash
cd ~
git clone https://github.com/seball/wifi-kiosk.git
cd wifi-kiosk
```

### 3. Uruchom skrypt instalacyjny

```bash
chmod +x scripts/*.sh
./scripts/install.sh
```

Skrypt automatycznie:
- Zainstaluje wymagane pakiety systemowe (hostapd, dnsmasq, nodejs, npm)
- Zainstaluje zależności Node.js
- Zbuduje frontend React
- Skonfiguruje uprawnienia

### 4. Konfiguracja automatycznego uruchamiania

Użyj nowego skryptu który automatycznie wykrywa usera:

```bash
./scripts/configure-services.sh
```

Skrypt automatycznie:
- Wykryje aktualnego usera i jego katalog home
- Skonfiguruje poprawne ścieżki w services
- Zainstaluje services systemd
- Włączy autostart backendu i GUI
- Skonfiguruje automatyczne logowanie (opcjonalnie)

**Stary skrypt** `setup-services.sh` nadal działa, ale przekieruje na nowy.

### 5. Restart systemu

```bash
sudo reboot
```

Po restarcie:
- Backend uruchomi się automatycznie
- GUI w trybie kiosk uruchomi się po zalogowaniu
- Aplikacja będzie dostępna pod adresem http://localhost

## 🖥️ Instalacja na Raspberry Pi OS Lite

Raspberry Pi OS Lite nie ma preinstalowanego środowiska graficznego. Aby uruchomić aplikację kiosk, musisz doinstalować minimalne GUI.

### 1. Instalacja środowiska graficznego

```bash
# Połącz się przez SSH
ssh pi@raspberrypi.local

# Aktualizuj system
sudo apt update && sudo apt upgrade -y

# Zainstaluj minimalny X11 (bez zbędnych pakietów)
sudo apt install -y --no-install-recommends \
    xserver-xorg \
    x11-xserver-utils \
    xinit \
    openbox

# Zainstaluj przeglądarkę (automatyczna detekcja nazwy pakietu)
sudo apt install -y --no-install-recommends chromium-browser unclutter
# Skrypty automatycznie wykrywają: chromium-browser, chromium, lub firefox-esr
```

### 2. Konfiguracja automatycznego startu GUI

```bash
# Włącz automatyczne logowanie do konsoli
sudo raspi-config nonint do_boot_behaviour B2

# Skonfiguruj automatyczny start X11
echo 'if [ -z "$DISPLAY" ] && [ "$XDG_VTNR" = 1 ]; then' >> ~/.bashrc
echo '  exec startx' >> ~/.bashrc
echo 'fi' >> ~/.bashrc
```

### 3. Konfiguracja .xinitrc

```bash
# Utwórz plik .xinitrc
cat > ~/.xinitrc << 'EOF'
#!/bin/bash

# Wyłącz wygaszacz ekranu
xset s off
xset -dpms
xset s noblank

# Ukryj kursor myszy
unclutter -idle 0.5 -root &

# Uruchom window manager
exec openbox-session &

# Czekaj chwilę na uruchomienie WM
sleep 2

# Uruchom aplikację kiosk
chromium-browser --noerrdialogs --kiosk --incognito http://localhost \
  --disable-translate --no-first-run --fast --fast-start \
  --disable-infobars --disable-features=TranslateUI \
  --disk-cache-dir=/dev/null --password-store=basic \
  --disable-pinch --overscroll-history-navigation=disabled \
  --disable-features=TouchpadOverscrollHistoryNavigation
EOF

chmod +x ~/.xinitrc
```

### 4. Instalacja aplikacji WiFi Kiosk

```bash
# Zainstaluj aplikację (jak w instrukcji standardowej)
cd ~
git clone https://github.com/seball/wifi-kiosk.git
cd wifi-kiosk
chmod +x scripts/*.sh
./scripts/install.sh
./scripts/setup-services.sh
```

### 5. Konfiguracja service tylko dla backendu

Na Lite wystarczy uruchomić tylko backend service:

```bash
# Wyłącz GUI service (nie jest potrzebne)
sudo systemctl disable wifi-kiosk-gui.service

# Backend będzie działał, GUI uruchomi .xinitrc
sudo systemctl enable wifi-kiosk-backend.service
sudo systemctl start wifi-kiosk-backend.service
```

### 6. Restart i test

```bash
sudo reboot
```

Po restarcie:
1. Pi loguje się automatycznie
2. Uruchamia się X11
3. Chromium otwiera się w trybie kiosk na localhost
4. Aplikacja WiFi Kiosk jest gotowa do użycia

### Troubleshooting dla Lite

**Problem: Czarny ekran po restarcie**
```bash
# Sprawdź logi X11
cat ~/.local/share/xorg/Xorg.0.log

# Sprawdź czy backend działa
sudo systemctl status wifi-kiosk-backend
```

**Problem: Przeglądarka nie uruchamia się**
```bash
# Sprawdź dostępne przeglądarki
command -v chromium-browser
command -v chromium  
command -v firefox-esr

# Test manual
DISPLAY=:0 chromium-browser --version
# lub
DISPLAY=:0 chromium --version

# Sprawdź backend
curl http://localhost
sudo netstat -tlnp | grep :80
```

**Problem: GUI nie uruchamia się automatycznie**
```bash
# Sprawdź autologowanie
sudo raspi-config nonint get_boot_behaviour

# Sprawdź .bashrc
tail ~/.bashrc
```

## 🔧 Konfiguracja dodatkowa

### Wyłączenie wygaszacza ekranu

```bash
# Edytuj lightdm.conf
sudo nano /etc/lightdm/lightdm.conf
```

W sekcji `[Seat:*]` dodaj:

```ini
xserver-command=X -s 0 -dpms
```

### Ukrycie kursora myszy

Zainstaluj unclutter:

```bash
sudo apt-get install unclutter
```

Dodaj do autostartu:

```bash
@unclutter -idle 0
```

### Rotacja ekranu (opcjonalnie)

W pliku `/boot/config.txt` dodaj:

```bash
# Rotacja 90 stopni
display_rotate=1
# Rotacja 180 stopni
# display_rotate=2
# Rotacja 270 stopni
# display_rotate=3
```

## 📱 Jak używać

1. **Włącz Raspberry Pi** - aplikacja uruchomi się automatycznie
2. **Znajdź hotspot** - szukaj sieci WiFi o nazwie `RaspberryPi-XXXXX`
3. **Zeskanuj QR kod** - wyświetlony na ekranie lub wpisz hasło ręcznie
4. **Otwórz przeglądarkę** - przejdź do `http://192.168.4.1`
5. **Wybierz sieć WiFi** - z listy dostępnych sieci
6. **Wprowadź hasło** - dla wybranej sieci
7. **Gotowe!** - Raspberry Pi połączy się z siecią i wyłączy hotspot

## 🔄 Aktualizacja aplikacji

### Automatyczna aktualizacja (z git)

```bash
cd ~/wifi-kiosk
./scripts/update.sh
```

Skrypt automatycznie:
- Pobierze najnowsze zmiany z git
- Zaktualizuje zależności
- Przebuduje frontend
- Zrestartuje services

### Ręczna przebudowa frontendu

Jeśli zmieniłeś tylko pliki frontendu:

```bash
cd ~/wifi-kiosk
./scripts/rebuild-frontend.sh
sudo systemctl restart wifi-kiosk-backend
```

### Tryb development

Do testowania bez ciągłego budowania:

```bash
# Terminal 1 - Frontend development
cd ~/wifi-kiosk/frontend
npm start

# Terminal 2 - Backend
cd ~/wifi-kiosk
./scripts/dev.sh
```

## 🛠️ Rozwiązywanie problemów

### Sprawdzanie logów

```bash
# Logi backendu
sudo journalctl -u wifi-kiosk-backend -f

# Logi GUI (kiosk)
sudo journalctl -u wifi-kiosk-gui -f

# Status services
sudo systemctl status wifi-kiosk-backend
sudo systemctl status wifi-kiosk-gui

# Logi systemowe
sudo journalctl -f
```

### Reset konfiguracji WiFi

```bash
# Przełącz w tryb hotspota
sudo /home/pi/wifi-kiosk/scripts/wifi-mode.sh ap

# Przełącz w tryb klienta
sudo /home/pi/wifi-kiosk/scripts/wifi-mode.sh client
```

### Problem z git (10k zmian)

Jeśli git pokazuje tysiące zmian z node_modules:

```bash
cd ~/wifi-kiosk
./fix-git.sh
git commit -m "Fix: Remove node_modules and add .gitignore"
git push
```

### Różnice między Full a Lite OS

| Problem | Raspberry Pi OS Full | Raspberry Pi OS Lite |
|---------|---------------------|----------------------|
| **GUI nie uruchamia się** | `sudo systemctl status wifi-kiosk-gui` | Sprawdź `~/.xinitrc` i `~/.bashrc` |
| **Autostart** | Używa systemd service | Używa .bashrc + startx |
| **Chromium problemy** | Sprawdź LXDE autostart | `DISPLAY=:0 chromium-browser --version` |
| **Brak GUI** | Zainstalowany domyślnie | Zainstaluj: `sudo apt install lxde-core` |
| **Service GUI** | Włącz: `wifi-kiosk-gui.service` | Wyłącz: `wifi-kiosk-gui.service` |

### Problemy z różnymi userami

**Nie ma usera `pi`:**
```bash
# Sprawdź aktualnego usera
whoami
ls -la /home/

# Użyj nowego skryptu konfiguracyjnego
./scripts/configure-services.sh
```

**Services nie startują:**
```bash
# Sprawdź czy ścieżki są poprawne
sudo systemctl cat wifi-kiosk-backend
sudo systemctl cat wifi-kiosk-gui

# Sprawdź czy katalog projektu istnieje
ls -la ~/wifi-kiosk/
```

**Autologowanie nie działa:**
```bash
# Sprawdź konfigurację autologin
sudo systemctl status getty@tty1
sudo raspi-config nonint get_boot_behaviour
```

**Problem z shellem (dash zamiast bash):**
```bash
# Sprawdź aktualny shell
echo $SHELL
getent passwd $USER | cut -d: -f7

# Zmień na bash jeśli potrzebny
sudo chsh -s /bin/bash $USER

# Sprawdź czy .bashrc jest wykonywany
echo "echo 'bashrc loaded'" >> ~/.bashrc
```

### Restart aplikacji

```bash
sudo systemctl restart wifi-kiosk-backend
```

## 🔐 Bezpieczeństwo

- Aplikacja wymaga uprawnień root do konfiguracji WiFi
- Hasła WiFi nie są szyfrowane w transmisji lokalnej
- Zalecane jest używanie w bezpiecznym środowisku
- Rozważ dodanie HTTPS dla produkcji

## 📝 Struktura projektu

```
wifi-kiosk/
├── backend/
│   ├── server.js             # Serwer Express.js z API
│   └── package.json          # Zależności backendu
├── frontend/
│   ├── src/
│   │   ├── App.js           # Główny komponent React
│   │   └── App.css          # Style aplikacji
│   ├── public/
│   ├── build/               # Zbudowana aplikacja React
│   └── package.json         # Zależności frontendu
├── scripts/
│   ├── install.sh           # Skrypt instalacyjny (Full OS)
│   ├── install-lite.sh      # Skrypt instalacyjny (Lite OS)
│   ├── setup-services.sh    # Konfiguracja autostartu
│   ├── update.sh            # Aktualizacja z git
│   ├── rebuild-frontend.sh  # Przebudowa frontendu
│   ├── dev.sh               # Tryb development
│   ├── start.sh             # Uruchomienie serwera
│   ├── start-kiosk.sh       # Uruchomienie w trybie kiosk
│   └── wifi-mode.sh         # Przełączanie trybu WiFi
├── service/
│   ├── wifi-kiosk.service   # Service dla backendu
│   └── wifi-kiosk-gui.service # Service dla GUI
├── .gitignore
├── CLAUDE.md                # Dokumentacja dla AI
└── README.md
```

## 🤝 Wkład w projekt

1. Fork repozytorium
2. Stwórz branch (`git checkout -b feature/AmazingFeature`)
3. Commit zmiany (`git commit -m 'Add some AmazingFeature'`)
4. Push branch (`git push origin feature/AmazingFeature`)
5. Otwórz Pull Request

## 📄 Licencja

Ten projekt jest dostępny na licencji MIT.

## 👥 Autorzy

- Sebastian - [@seball](https://github.com/seball)

## 🙏 Podziękowania

- Raspberry Pi Foundation
- Społeczność React
- Twórcy hostapd i dnsmasq
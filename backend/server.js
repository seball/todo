const express = require("express");
const bodyParser = require("body-parser");
const fs = require("fs");
const { exec, execSync } = require("child_process");
const path = require("path");

const app = express();
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: false }));

// Serwuj pliki React build
app.use(express.static(path.join(__dirname, "../frontend/build")));

// Stan aplikacji
let currentMode = "init"; // init, hotspot, connected
let hotspotInfo = null;

// Funkcja sprawdzająca stan WiFi
const checkWifiStatus = () => {
  try {
    // Sprawdź czy interfejs wlan0 ma adres IP (jest połączony)
    const result = execSync("ip addr show wlan0 | grep 'inet ' | awk '{print $2}'", { encoding: 'utf8' });
    if (result.trim()) {
      console.log("WiFi już połączone, ustawiam tryb 'connected'");
      currentMode = "connected";
      return true;
    }
  } catch (error) {
    console.log("Nie udało się sprawdzić stanu WiFi, pozostaję w trybie init");
  }
  return false;
};

// Sprawdź stan WiFi przy starcie
checkWifiStatus();

// Endpoint do sprawdzania statusu
app.get("/api/status", (req, res) => {
  res.json({ 
    mode: currentMode,
    hotspotInfo: hotspotInfo 
  });
});

// Endpoint do uruchamiania hotspota
app.post("/api/start-hotspot", async (req, res) => {
  try {
    // Generuj losowe dane hotspota
    const ssid = `RaspberryPi-${Math.random().toString(36).substring(7)}`;
    const password = Math.random().toString(36).substring(2, 10);
    
    // Konfiguracja hostapd
    const hostapdConfig = `
interface=wlan0
driver=nl80211
ssid=${ssid}
hw_mode=g
channel=7
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=${password}
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
`;

    // Konfiguracja dnsmasq
    const dnsmasqConfig = `
interface=wlan0
dhcp-range=192.168.4.2,192.168.4.20,255.255.255.0,24h
domain=local
address=/local/192.168.4.1
`;

    // Zapisz konfiguracje
    fs.writeFileSync("/tmp/hostapd.conf", hostapdConfig);
    fs.writeFileSync("/tmp/dnsmasq.conf", dnsmasqConfig);
    
    // Przełącz w tryb AP
    exec(`sudo bash -c '
      systemctl stop wpa_supplicant
      ip link set wlan0 down
      ip addr flush dev wlan0
      ip link set wlan0 up
      ip addr add 192.168.4.1/24 dev wlan0
      
      # Uruchom hostapd i dnsmasq
      killall hostapd dnsmasq 2>/dev/null || true
      hostapd /tmp/hostapd.conf -B
      dnsmasq -C /tmp/dnsmasq.conf
      
      # Włącz routing
      echo 1 > /proc/sys/net/ipv4/ip_forward
      iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
      iptables -A FORWARD -i wlan0 -o eth0 -j ACCEPT
      iptables -A FORWARD -i eth0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT
    '`, (err, stdout, stderr) => {
      if (err) {
        console.error("Błąd uruchamiania hotspota:", err);
        return res.status(500).json({ error: "Nie można uruchomić hotspota" });
      }
      
      currentMode = "hotspot";
      hotspotInfo = { ssid, password };
      res.json(hotspotInfo);
    });
    
  } catch (err) {
    console.error("Błąd:", err);
    res.status(500).json({ error: "Błąd serwera" });
  }
});

// Endpoint do skanowania sieci WiFi
app.get("/api/scan-wifi", (req, res) => {
  exec("sudo iwlist wlan0 scan | grep -E 'ESSID:|Quality='", (err, stdout) => {
    if (err) {
      return res.status(500).json({ error: "Nie można zeskanować sieci" });
    }
    
    const lines = stdout.split("\n");
    const networks = [];
    
    for (let i = 0; i < lines.length - 1; i += 2) {
      const qualityMatch = lines[i].match(/Quality=(\d+)\/70/);
      const ssidMatch = lines[i + 1].match(/ESSID:"(.+)"/);
      
      if (qualityMatch && ssidMatch) {
        const signal = Math.round((parseInt(qualityMatch[1]) / 70) * 100);
        networks.push({
          ssid: ssidMatch[1],
          signal: signal
        });
      }
    }
    
    // Usuń duplikaty i posortuj po sile sygnału
    const uniqueNetworks = networks.filter((net, index, self) =>
      index === self.findIndex((n) => n.ssid === net.ssid)
    ).sort((a, b) => b.signal - a.signal);
    
    res.json({ networks: uniqueNetworks });
  });
});

// Endpoint do łączenia z WiFi
app.post("/api/connect-wifi", (req, res) => {
  const { ssid, password } = req.body;
  
  if (!ssid || !password) {
    return res.status(400).json({ error: "Brak SSID lub hasła" });
  }
  
  // Prosty test - próbuj połączyć z timeout
  exec(`sudo bash -c '
    # Zatrzymaj AP tymczasowo
    killall hostapd dnsmasq 2>/dev/null || true
    
    # Przywróć tryb klienta
    ip addr flush dev wlan0
    systemctl start wpa_supplicant
    
    # Skonfiguruj nową sieć
    wpa_cli -i wlan0 remove_network all
    NETWORK_ID=$(wpa_cli -i wlan0 add_network | tail -n 1)
    wpa_cli -i wlan0 set_network $NETWORK_ID ssid \\"${ssid}\\"
    wpa_cli -i wlan0 set_network $NETWORK_ID psk \\"${password}\\"
    wpa_cli -i wlan0 enable_network $NETWORK_ID
    wpa_cli -i wlan0 save_config
    
    # Poczekaj na połączenie - max 20 sekund
    for i in {1..20}; do
      if wpa_cli -i wlan0 status | grep -q "wpa_state=COMPLETED"; then
        echo "CONNECTION_SUCCESS"
        exit 0
      fi
      sleep 1
    done
    
    echo "CONNECTION_FAILED"
    exit 1
  '`, (err, stdout, stderr) => {
    console.log("Connection attempt:", stdout, stderr);
    
    if (!err && stdout.includes("CONNECTION_SUCCESS")) {
      // Sukces - połączono z nową siecią
      currentMode = "connected";
      res.json({ success: true, message: "Połączono z nową siecią WiFi" });
    } else {
      // Niepowodzenie - przywróć hotspot
      console.log("Connection failed, restoring hotspot...");
      
      // Przywróć hotspot z tymi samymi danymi
      exec(`sudo bash -c '
        systemctl stop wpa_supplicant
        ip link set wlan0 down
        ip addr flush dev wlan0
        ip link set wlan0 up
        ip addr add 192.168.4.1/24 dev wlan0
        
        # Uruchom hostapd i dnsmasq ponownie
        hostapd /tmp/hostapd.conf -B
        dnsmasq -C /tmp/dnsmasq.conf
        
        # Włącz routing
        echo 1 > /proc/sys/net/ipv4/ip_forward
        iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE 2>/dev/null || true
        iptables -A FORWARD -i wlan0 -o eth0 -j ACCEPT 2>/dev/null || true
        iptables -A FORWARD -i eth0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
      '`, (restoreErr) => {
        if (restoreErr) {
          console.error("Error restoring hotspot:", restoreErr);
        }
        res.status(400).json({ 
          error: "Nie udało się połączyć. Sprawdź SSID i hasło. Hotspot przywrócony.",
          keepHotspot: true 
        });
      });
    }
  });
});

// Stara funkcjonalność dla kompatybilności
app.post("/connect", (req, res) => {
  const { ssid, password } = req.body;
  const config = `
interface wlan0
static ip_address=192.168.1.100/24
static routers=192.168.1.1
static domain_name_servers=192.168.1.1 8.8.8.8

network={
  ssid="${ssid}"
  psk="${password}"
}`;
  
  fs.writeFileSync("/etc/dhcpcd.conf", config);
  exec("sudo systemctl restart dhcpcd", (err) => {
    if (err) return res.status(500).send("Błąd połączenia");
    res.send("Połączono z siecią Wi-Fi");
  });
});

// Endpoint do resetowania na tryb hotspot (jeśli chcemy zmienić sieć)
app.post("/api/reset-to-hotspot", (req, res) => {
  console.log("Resetowanie do trybu hotspot...");
  currentMode = "init";
  hotspotInfo = null;
  res.json({ success: true, message: "Reset do trybu hotspot" });
});

// Dla React Router - wszystkie inne ścieżki zwracają index.html
app.get("*", (req, res) => {
  res.sendFile(path.join(__dirname, "../frontend/build", "index.html"));
});

app.listen(80, () => {
  console.log("Serwer działa na porcie 80");
  console.log("Tryb kiosku WiFi aktywny");
});
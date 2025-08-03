const express = require("express");
const { exec, execSync } = require("child_process");
const path = require("path");
const { promisify } = require('util');
const execAsync = promisify(exec);

const app = express();
app.use(express.json());

// Serwuj pliki React build
app.use(express.static(path.join(__dirname, "../frontend/build")));

// Stan aplikacji
let currentMode = "init"; // init, hotspot, connected
let hotspotInfo = null;

// Funkcja sprawdzająca stan WiFi używając NetworkManager
const checkWifiStatus = async () => {
  try {
    // Sprawdź aktywne połączenia
    const { stdout } = await execAsync("nmcli -t -f NAME,TYPE,DEVICE con show --active");
    const connections = stdout.trim().split('\n');
    
    for (const conn of connections) {
      const [name, type, device] = conn.split(':');
      if (device === 'wlan0' && type === '802-11-wireless') {
        // Sprawdź czy to AP czy klient
        const { stdout: mode } = await execAsync(`nmcli -t -f 802-11-wireless.mode con show "${name}"`);
        
        if (mode.includes('ap')) {
          currentMode = "hotspot";
          // Pobierz dane hotspotu
          const { stdout: ssid } = await execAsync(`nmcli -t -f 802-11-wireless.ssid con show "${name}"`);
          const { stdout: psk } = await execAsync(`nmcli -t -f 802-11-wireless-security.psk con show "${name}"`);
          hotspotInfo = {
            ssid: ssid.split(':')[1]?.trim() || 'TodoAP',
            password: psk.split(':')[1]?.trim() || 'todo12345678'
          };
        } else {
          currentMode = "connected";
        }
        return true;
      }
    }
  } catch (error) {
    console.log("Nie udało się sprawdzić stanu WiFi:", error.message);
  }
  return false;
};

// Sprawdź stan WiFi przy starcie
setTimeout(async () => {
  console.log("Sprawdzanie stanu WiFi po starcie...");
  await checkWifiStatus();
}, 3000);

// Endpoint do sprawdzania statusu
app.get("/api/status", async (req, res) => {
  if (currentMode === "init") {
    await checkWifiStatus();
  }
  
  res.json({ 
    mode: currentMode,
    hotspotInfo: hotspotInfo 
  });
});

// Endpoint do uruchamiania hotspota z NetworkManager
app.post("/api/start-hotspot", async (req, res) => {
  console.log("[START-HOTSPOT] Rozpoczynam tworzenie hotspota...");
  
  try {
    // Używaj stałej nazwy SSID
    const ssid = `TOMAK69`;
    const password = "tomak12345";
    console.log(`[START-HOTSPOT] SSID: ${ssid}, Password: ${password}`);
    
    // Sprawdź obecny stan
    console.log("[START-HOTSPOT] Sprawdzam obecne połączenia...");
    const { stdout: currentCons } = await execAsync('nmcli con show');
    console.log("[START-HOTSPOT] Połączenia:", currentCons);
    
    // Usuń stare połączenie AP jeśli istnieje
    try {
      console.log("[START-HOTSPOT] Usuwam stare TodoAP...");
      await execAsync('nmcli con delete "TodoAP"');
      console.log("[START-HOTSPOT] Stare TodoAP usunięte");
    } catch (e) {
      console.log("[START-HOTSPOT] TodoAP nie istniało (OK)");
    }
    
    // Utwórz nowe połączenie AP
    console.log("[START-HOTSPOT] Tworzę nowe połączenie AP...");
    const { stdout: addResult } = await execAsync(`nmcli con add type wifi ifname wlan0 con-name TodoAP autoconnect no ssid "${ssid}"`);
    console.log("[START-HOTSPOT] Add result:", addResult);
    
    console.log("[START-HOTSPOT] Konfiguruję parametry AP...");
    await execAsync('nmcli con modify TodoAP 802-11-wireless.mode ap');
    await execAsync('nmcli con modify TodoAP 802-11-wireless.band bg');
    await execAsync('nmcli con modify TodoAP ipv4.method shared');
    await execAsync('nmcli con modify TodoAP ipv4.addresses 192.168.100.1/24');
    await execAsync('nmcli con modify TodoAP wifi-sec.key-mgmt wpa-psk');
    await execAsync(`nmcli con modify TodoAP wifi-sec.psk "${password}"`);
    console.log("[START-HOTSPOT] Konfiguracja AP zakończona");
    
    // Aktywuj AP
    console.log("[START-HOTSPOT] Aktywuję AP...");
    const { stdout: upResult } = await execAsync('nmcli con up TodoAP');
    console.log("[START-HOTSPOT] Up result:", upResult);
    
    // Sprawdź status
    const { stdout: finalStatus } = await execAsync('nmcli con show --active');
    console.log("[START-HOTSPOT] Aktywne połączenia po aktywacji:", finalStatus);
    
    currentMode = "hotspot";
    hotspotInfo = { ssid, password };
    console.log("[START-HOTSPOT] Sukces! Hotspot utworzony");
    res.json(hotspotInfo);
    
  } catch (error) {
    console.error("[START-HOTSPOT] BŁĄD:", error.message);
    console.error("[START-HOTSPOT] Stack:", error.stack);
    if (error.stdout) console.error("[START-HOTSPOT] stdout:", error.stdout);
    if (error.stderr) console.error("[START-HOTSPOT] stderr:", error.stderr);
    res.status(500).json({ error: "Nie można uruchomić hotspota", details: error.message });
  }
});

// Endpoint do skanowania sieci WiFi
app.get("/api/scan-networks", async (req, res) => {
  console.log("[SCAN-NETWORKS] Rozpoczynam skanowanie sieci WiFi...");
  
  try {
    // Wymuś nowe skanowanie
    console.log("[SCAN-NETWORKS] Uruchamiam rescan...");
    const { stdout: rescanResult } = await execAsync('nmcli dev wifi rescan');
    console.log("[SCAN-NETWORKS] Rescan result:", rescanResult);
    
    await new Promise(resolve => setTimeout(resolve, 3000)); // Poczekaj na wyniki
    console.log("[SCAN-NETWORKS] Pobieram listę sieci...");
    
    // Pobierz listę sieci
    const { stdout } = await execAsync('nmcli -t -f SSID,SIGNAL,SECURITY dev wifi list');
    console.log("[SCAN-NETWORKS] Raw output:", stdout);
    
    const networks = stdout.trim().split('\n')
      .filter(line => line)
      .map(line => {
        const [ssid, signal, security] = line.split(':');
        return {
          ssid,
          signal: parseInt(signal),
          security: security || 'Open'
        };
      })
      .filter(net => net.ssid && net.ssid !== '--')
      .sort((a, b) => b.signal - a.signal);
    
    console.log(`[SCAN-NETWORKS] Znaleziono ${networks.length} sieci:`, networks.map(n => `${n.ssid} (${n.signal}%)`));
    res.json({ networks });
    
  } catch (error) {
    console.error("[SCAN-NETWORKS] BŁĄD:", error.message);
    console.error("[SCAN-NETWORKS] Stack:", error.stack);
    if (error.stdout) console.error("[SCAN-NETWORKS] stdout:", error.stdout);
    if (error.stderr) console.error("[SCAN-NETWORKS] stderr:", error.stderr);
    res.status(500).json({ error: "Nie można zeskanować sieci" });
  }
});

// Endpoint do łączenia z siecią WiFi
app.post("/api/connect-wifi", async (req, res) => {
  const { ssid, password } = req.body;
  
  if (!ssid) {
    return res.status(400).json({ error: "Brak SSID" });
  }
  
  try {
    // Wyłącz AP tymczasowo
    await execAsync('nmcli con down TodoAP 2>/dev/null || true');
    
    // Usuń stare połączenie jeśli istnieje
    try {
      await execAsync(`nmcli con delete "${ssid}" 2>/dev/null`);
    } catch (e) {
      // Ignoruj błąd
    }
    
    // Utwórz nowe połączenie
    if (password) {
      await execAsync(`nmcli dev wifi connect "${ssid}" password "${password}" ifname wlan0`);
    } else {
      await execAsync(`nmcli dev wifi connect "${ssid}" ifname wlan0`);
    }
    
    // Poczekaj na połączenie
    await new Promise(resolve => setTimeout(resolve, 5000));
    
    // Sprawdź czy połączono
    const { stdout } = await execAsync('nmcli -t -f STATE,CONNECTION dev show wlan0');
    
    if (stdout.includes('connected') && !stdout.includes('TodoAP')) {
      currentMode = "connected";
      res.json({ success: true, message: "Połączono z siecią WiFi" });
    } else {
      throw new Error("Połączenie nieudane");
    }
    
  } catch (error) {
    console.error("Błąd łączenia:", error);
    
    // Przywróć AP
    try {
      await execAsync('nmcli con up TodoAP');
      currentMode = "hotspot";
    } catch (e) {
      console.error("Błąd przywracania AP:", e);
    }
    
    res.status(400).json({ 
      error: "Nie udało się połączyć. Sprawdź hasło.",
      keepHotspot: true,
      mode: "hotspot",
      hotspotInfo: hotspotInfo
    });
  }
});

// Endpoint do resetowania na tryb hotspot
app.post("/api/reset-to-hotspot", async (req, res) => {
  console.log("[RESET-HOTSPOT] Rozpoczynam reset do trybu hotspot...");
  
  try {
    // Sprawdź obecny stan
    const { stdout: beforeStatus } = await execAsync('nmcli con show --active');
    console.log("[RESET-HOTSPOT] Stan przed resetem:", beforeStatus);
    
    // Rozłącz obecne połączenie
    console.log("[RESET-HOTSPOT] Rozłączam wlan0...");
    const { stdout: disconnectResult } = await execAsync('nmcli dev disconnect wlan0');
    console.log("[RESET-HOTSPOT] Disconnect result:", disconnectResult);
    
    // Sprawdź czy TodoAP istnieje
    const { stdout: conList } = await execAsync('nmcli con show');
    console.log("[RESET-HOTSPOT] Lista połączeń:", conList);
    
    if (!conList.includes('TodoAP')) {
      console.log("[RESET-HOTSPOT] TodoAP nie istnieje - tworzę nowy...");
      
      // Utwórz nowy AP z aktualnymi danymi
      const ssid = 'TOMAK69';
      const password = 'tomak12345';
      
      await execAsync(`nmcli con add type wifi ifname wlan0 con-name TodoAP autoconnect no ssid "${ssid}"`);
      await execAsync('nmcli con modify TodoAP 802-11-wireless.mode ap');
      await execAsync('nmcli con modify TodoAP 802-11-wireless.band bg');
      await execAsync('nmcli con modify TodoAP ipv4.method shared');
      await execAsync('nmcli con modify TodoAP ipv4.addresses 192.168.100.1/24');
      await execAsync('nmcli con modify TodoAP wifi-sec.key-mgmt wpa-psk');
      await execAsync(`nmcli con modify TodoAP wifi-sec.psk "${password}"`);
      
      // Ustaw hotspotInfo
      hotspotInfo = { ssid, password };
      console.log("[RESET-HOTSPOT] Nowy TodoAP utworzony");
    }
    
    // Aktywuj AP
    console.log("[RESET-HOTSPOT] Aktywuję TodoAP...");
    const { stdout: upResult } = await execAsync('nmcli con up TodoAP');
    console.log("[RESET-HOTSPOT] Up result:", upResult);
    
    // Sprawdź końcowy stan
    const { stdout: afterStatus } = await execAsync('nmcli con show --active');
    console.log("[RESET-HOTSPOT] Stan po resecie:", afterStatus);
    
    currentMode = "hotspot";
    console.log("[RESET-HOTSPOT] Sukces! Przełączono na tryb hotspot");
    res.json({ success: true, message: "Reset do trybu hotspot" });
    
  } catch (error) {
    console.error("[RESET-HOTSPOT] BŁĄD:", error.message);
    console.error("[RESET-HOTSPOT] Stack:", error.stack);
    if (error.stdout) console.error("[RESET-HOTSPOT] stdout:", error.stdout);
    if (error.stderr) console.error("[RESET-HOTSPOT] stderr:", error.stderr);
    res.status(500).json({ error: "Błąd resetowania", details: error.message });
  }
});

// Catch-all dla React Router
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, '../frontend/build', 'index.html'));
});

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
  console.log(`Serwer działa na porcie ${PORT}`);
});
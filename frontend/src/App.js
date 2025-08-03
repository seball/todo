import React, { useState, useEffect } from 'react';
import QRCode from 'qrcode';
import './App.css';

const ConnectingOverlay = ({ selectedNetwork }) => (
  <div className="connecting-overlay">
    <div className="connecting-content">
      <div className="spinner spinner-large"></div>
      <h2>Łączenie z siecią</h2>
      <p>Łączenie z siecią "{selectedNetwork}"...</p>
      <p>Może to potrwać do 20 sekund</p>
    </div>
  </div>
);

function App() {
  const [mode, setMode] = useState('loading'); // loading, hotspot, configuring, connected
  const [hotspotInfo, setHotspotInfo] = useState(null);
  const [networks, setNetworks] = useState([]);
  const [selectedNetwork, setSelectedNetwork] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [isConnecting, setIsConnecting] = useState(false);

  useEffect(() => {
    checkStatus();
  }, []);

  const checkStatus = async () => {
    try {
      const response = await fetch('/api/status');
      const data = await response.json();
      
      if (data.mode === 'hotspot') {
        setMode('hotspot');
        setHotspotInfo(data.hotspotInfo);
      } else if (data.mode === 'connected') {
        setMode('connected');
      } else {
        setMode('hotspot');
        startHotspot();
      }
    } catch (err) {
      console.error('Błąd sprawdzania statusu:', err);
      setMode('hotspot');
      startHotspot();
    }
  };

  const startHotspot = async () => {
    try {
      const response = await fetch('/api/start-hotspot', { method: 'POST' });
      const data = await response.json();
      setHotspotInfo(data);
      setMode('hotspot');
      
      // Generuj QR kod po otrzymaniu informacji o hotspot
      setTimeout(() => {
        generateQRCode(data.ssid, data.password);
      }, 100);
    } catch (err) {
      setError('Nie można uruchomić hotspota');
    }
  };

  const generateQRCode = async (ssid, password) => {
    try {
      const wifiString = `WIFI:T:WPA;S:${ssid};P:${password};;`;
      const canvas = document.getElementById('qr-code');
      if (canvas) {
        await QRCode.toCanvas(canvas, wifiString, {
          width: 160,
          margin: 1,
          scale: 1,
          color: {
            dark: '#000000',
            light: '#faf5f0'
          }
        });
      }
    } catch (err) {
      console.error('Błąd generowania QR kodu:', err);
    }
  };

  const scanNetworks = async () => {
    setMode('configuring');
    try {
      const response = await fetch('/api/scan-wifi');
      const data = await response.json();
      setNetworks(data.networks);
    } catch (err) {
      setError('Nie można zeskanować sieci');
    }
  };


  const connectToWifi = async (e) => {
    e.preventDefault();
    setError('');
    
    setIsConnecting(true);
    
    try {
      const response = await fetch('/api/connect-wifi', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ ssid: selectedNetwork, password })
      });
      
      if (response.ok) {
        setMode('connected');
        setError('');
                setIsConnecting(false);
      } else {
        const data = await response.json();
        setError(data.error || 'Błąd połączenia');
                setIsConnecting(false);
        
        // Jeśli backend przywrócił hotspot, zaktualizuj stan
        if (data.keepHotspot && data.mode === 'hotspot') {
          console.log('Powrót do trybu hotspot po nieudanej próbie połączenia');
          setMode('hotspot');
          if (data.hotspotInfo) {
            setHotspotInfo(data.hotspotInfo);
            // Regeneruj QR kod
            setTimeout(() => {
              generateQRCode(data.hotspotInfo.ssid, data.hotspotInfo.password);
            }, 100);
          }
        }
      }
    } catch (err) {
      setError('Błąd połączenia z siecią');
            setIsConnecting(false);
    }
  };

  if (mode === 'loading') {
    return (
      <div className="App">
        <h1>Ładowanie...</h1>
      </div>
    );
  }

  if (mode === 'hotspot' && hotspotInfo) {
    return (
      <div className="App">
        <h1>Konfiguracja WiFi</h1>
                <div className="hotspot-info">
          <div className="qr-section">
            <div className="qr-code">
              <canvas id="qr-code"></canvas>
            </div>
          </div>
          <div className="instructions">
            <h3>Jak się połączyć?</h3>
            <ol>
              <li>Zeskanuj kod QR telefonem</li>
              <li>Połącz się z siecią WiFi</li>
              <li>Otwórz przeglądarkę na 192.168.4.1</li>
            </ol>
            <button onClick={scanNetworks} style={{ marginTop: '20px' }}>
              Konfiguruj WiFi
            </button>
          </div>
        </div>
      </div>
    );
  }

  if (mode === 'configuring') {
    return (
      <>
        {isConnecting && <ConnectingOverlay selectedNetwork={selectedNetwork} />}
        <div className="App">
          <h1>Wybierz sieć WiFi</h1>
          {error && <p className="error">{error}</p>}
                    <form onSubmit={connectToWifi}>
          <select 
            value={selectedNetwork} 
            onChange={(e) => setSelectedNetwork(e.target.value)}
            required
          >
            <option value="">Wybierz sieć</option>
            {networks.map(network => (
              <option key={network.ssid} value={network.ssid}>
                {network.ssid} ({network.signal}%)
              </option>
            ))}
          </select>
          <input
            type="password"
            placeholder="Hasło WiFi (min. 8 znaków)"
            value={password}
            onChange={(e) => {
              setPassword(e.target.value);
              // Wyczyść błędy przy zmianie hasła
              if (error && error.includes('Hasło')) {
                setError('');
              }
            }}
            required
            minLength="8"
            maxLength="63"
          />
          <button type="submit" disabled={isConnecting}>
            {isConnecting ? (
              <>
                <span className="spinner"></span>
                Łączenie...
              </>
            ) : (
              'Połącz'
            )}
          </button>
        </form>
        </div>
      </>
    );
  }

  const resetToHotspot = async () => {
    try {
      await fetch('/api/reset-to-hotspot', { method: 'POST' });
      setMode('loading');
      checkStatus();
    } catch (err) {
      console.error('Błąd resetowania:', err);
    }
  };

  if (mode === 'connected') {
    return (
      <div className="App">
        <h1>Połączono z WiFi!</h1>
        <p>Urządzenie jest teraz połączone z internetem.</p>
        <button onClick={resetToHotspot} style={{ marginTop: '20px', background: 'rgba(250, 245, 240, 0.1)', border: '1px solid rgba(250, 245, 240, 0.3)' }}>
          Zmień sieć WiFi
        </button>
      </div>
    );
  }

  return null;
}

export default App;
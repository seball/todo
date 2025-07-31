import React, { useState, useEffect } from 'react';
import QRCode from 'qrcode';
import './App.css';

function App() {
  const [mode, setMode] = useState('loading'); // loading, hotspot, configuring, connected
  const [hotspotInfo, setHotspotInfo] = useState(null);
  const [networks, setNetworks] = useState([]);
  const [selectedNetwork, setSelectedNetwork] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');

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
            dark: '#1e3c72',
            light: '#FFFFFF'
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
    
    try {
      const response = await fetch('/api/connect-wifi', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ ssid: selectedNetwork, password })
      });
      
      if (response.ok) {
        setMode('connected');
      } else {
        const data = await response.json();
        setError(data.error || 'Błąd połączenia');
      }
    } catch (err) {
      setError('Błąd połączenia z siecią');
    }
  };

  if (mode === 'loading') {
    return <div className="App"><h1>Ładowanie...</h1></div>;
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
          </div>
        </div>
      </div>
    );
  }

  if (mode === 'configuring') {
    return (
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
            placeholder="Hasło WiFi"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
          />
          <button type="submit">Połącz</button>
        </form>
      </div>
    );
  }

  if (mode === 'connected') {
    return (
      <div className="App">
        <h1>Połączono z WiFi!</h1>
        <p>Urządzenie jest teraz połączone z internetem.</p>
      </div>
    );
  }

  return null;
}

export default App;
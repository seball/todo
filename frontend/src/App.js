import React, { useState, useEffect } from 'react';
import QRCode from 'qrcode';
import './App.css';

const CalibrationGrid = () => {
  // Generuj markery pozycji
  const positionMarkers = [];
  
  // Markery co 100px w poziomie
  for (let x = 0; x <= 800; x += 100) {
    positionMarkers.push(
      <div 
        key={`x-${x}`} 
        className="position-marker" 
        style={{ left: `${x}px`, top: '25px', background: '#ffff00' }}
      >
        {x}
      </div>
    );
  }
  
  // Markery co 100px w pionie
  for (let y = 0; y <= 600; y += 100) {
    positionMarkers.push(
      <div 
        key={`y-${y}`} 
        className="position-marker" 
        style={{ top: `${y}px`, left: '25px', background: '#ffff00' }}
      >
        {y}
      </div>
    );
  }
  
  return (
    <div className="calibration-grid">
      {/* Linijki */}
      <div className="ruler-x"></div>
      <div className="ruler-y"></div>
      
      {/* Obszar roboczy 480x320 */}
      <div className="work-area">
        <div style={{
          position: 'absolute',
          top: '50%',
          left: '50%',
          transform: 'translate(-50%, -50%)',
          background: 'rgba(0, 255, 0, 0.9)',
          color: '#000',
          padding: '5px 10px',
          borderRadius: '5px',
          fontWeight: 'bold',
          fontSize: '14px'
        }}>
          480x320
        </div>
      </div>
      
      {/* Markery pozycji */}
      {positionMarkers}
      
      {/* Etykiety */}
      <div className="dimension-marker work-area-label">Obszar roboczy</div>
      <div className="dimension-marker screen-size">Ekran: {window.innerWidth}x{window.innerHeight}</div>
      
      {/* Dodatkowe obszary robocze do testowania */}
      <div style={{
        position: 'absolute',
        top: '0',
        left: '500px',
        width: '480px',
        height: '320px',
        border: '2px dashed #0080ff',
        background: 'rgba(0, 128, 255, 0.05)'
      }}>
        <div style={{
          position: 'absolute',
          top: '5px',
          left: '5px',
          background: 'rgba(0, 128, 255, 0.9)',
          color: '#fff',
          padding: '2px 5px',
          fontSize: '10px',
          borderRadius: '3px'
        }}>
          Przesunięty +500px
        </div>
      </div>
    </div>
  );
};

function App() {
  const [mode, setMode] = useState('loading'); // loading, hotspot, configuring, connected
  const [hotspotInfo, setHotspotInfo] = useState(null);
  const [networks, setNetworks] = useState([]);
  const [selectedNetwork, setSelectedNetwork] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [showGrid, setShowGrid] = useState(true); // Domyślnie włączona siatka
  const [offsetX, setOffsetX] = useState(0); // Przesunięcie obszaru roboczego

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
    return (
      <>
        {showGrid && <CalibrationGrid />}
        <div className="App" style={{ left: `${offsetX}px` }}>
          <h1>Ładowanie...</h1>
        </div>
        <button className="grid-toggle" onClick={() => setShowGrid(!showGrid)}>
          {showGrid ? 'Ukryj siatkę' : 'Pokaż siatkę'}
        </button>
        {showGrid && (
          <div style={{
            position: 'fixed',
            bottom: '50px',
            right: '10px',
            zIndex: 10000,
            background: 'rgba(255, 255, 255, 0.9)',
            padding: '10px',
            borderRadius: '5px',
            fontFamily: 'monospace',
            fontSize: '12px'
          }}>
            <div>Pozycja X: {offsetX}px</div>
            <button onClick={() => setOffsetX(offsetX - 10)} style={{ margin: '2px' }}>← -10</button>
            <button onClick={() => setOffsetX(offsetX + 10)} style={{ margin: '2px' }}>→ +10</button>
            <button onClick={() => setOffsetX(0)} style={{ margin: '2px' }}>Reset</button>
          </div>
        )}
      </>
    );
  }

  if (mode === 'hotspot' && hotspotInfo) {
    return (
      <>
        {showGrid && <CalibrationGrid />}
        <div className="App" style={{ left: `${offsetX}px` }}>
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
        <button className="grid-toggle" onClick={() => setShowGrid(!showGrid)}>
          {showGrid ? 'Ukryj siatkę' : 'Pokaż siatkę'}
        </button>
        {showGrid && (
          <div style={{
            position: 'fixed',
            bottom: '50px',
            right: '10px',
            zIndex: 10000,
            background: 'rgba(255, 255, 255, 0.9)',
            padding: '10px',
            borderRadius: '5px',
            fontFamily: 'monospace',
            fontSize: '12px'
          }}>
            <div>Pozycja X: {offsetX}px</div>
            <button onClick={() => setOffsetX(offsetX - 10)} style={{ margin: '2px' }}>← -10</button>
            <button onClick={() => setOffsetX(offsetX + 10)} style={{ margin: '2px' }}>→ +10</button>
            <button onClick={() => setOffsetX(0)} style={{ margin: '2px' }}>Reset</button>
          </div>
        )}
      </>
    );
  }

  if (mode === 'configuring') {
    return (
      <>
        {showGrid && <CalibrationGrid />}
        <div className="App" style={{ left: `${offsetX}px` }}>
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
        <button className="grid-toggle" onClick={() => setShowGrid(!showGrid)}>
          {showGrid ? 'Ukryj siatkę' : 'Pokaż siatkę'}
        </button>
        {showGrid && (
          <div style={{
            position: 'fixed',
            bottom: '50px',
            right: '10px',
            zIndex: 10000,
            background: 'rgba(255, 255, 255, 0.9)',
            padding: '10px',
            borderRadius: '5px',
            fontFamily: 'monospace',
            fontSize: '12px'
          }}>
            <div>Pozycja X: {offsetX}px</div>
            <button onClick={() => setOffsetX(offsetX - 10)} style={{ margin: '2px' }}>← -10</button>
            <button onClick={() => setOffsetX(offsetX + 10)} style={{ margin: '2px' }}>→ +10</button>
            <button onClick={() => setOffsetX(0)} style={{ margin: '2px' }}>Reset</button>
          </div>
        )}
      </>
    );
  }

  if (mode === 'connected') {
    return (
      <>
        {showGrid && <CalibrationGrid />}
        <div className="App" style={{ left: `${offsetX}px` }}>
          <h1>Połączono z WiFi!</h1>
          <p>Urządzenie jest teraz połączone z internetem.</p>
        </div>
        <button className="grid-toggle" onClick={() => setShowGrid(!showGrid)}>
          {showGrid ? 'Ukryj siatkę' : 'Pokaż siatkę'}
        </button>
        {showGrid && (
          <div style={{
            position: 'fixed',
            bottom: '50px',
            right: '10px',
            zIndex: 10000,
            background: 'rgba(255, 255, 255, 0.9)',
            padding: '10px',
            borderRadius: '5px',
            fontFamily: 'monospace',
            fontSize: '12px'
          }}>
            <div>Pozycja X: {offsetX}px</div>
            <button onClick={() => setOffsetX(offsetX - 10)} style={{ margin: '2px' }}>← -10</button>
            <button onClick={() => setOffsetX(offsetX + 10)} style={{ margin: '2px' }}>→ +10</button>
            <button onClick={() => setOffsetX(0)} style={{ margin: '2px' }}>Reset</button>
          </div>
        )}
      </>
    );
  }

  return null;
}

export default App;
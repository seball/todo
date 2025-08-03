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
  const [isMobile, setIsMobile] = useState(false);
  const [isKiosk, setIsKiosk] = useState(false);

  useEffect(() => {
    checkStatus();
    detectDevice();
  }, []);

  const detectDevice = () => {
    const userAgent = navigator.userAgent.toLowerCase();
    const isMobileDevice = /android|iphone|ipad|ipod|blackberry|iemobile|opera mini/.test(userAgent);
    const isRaspberryPi = window.location.hostname === '192.168.100.1' || 
                          window.location.hostname === 'localhost' ||
                          window.location.hostname === '127.0.0.1';
    
    setIsMobile(isMobileDevice);
    setIsKiosk(isRaspberryPi && !isMobileDevice);
  };

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
    setError('');
    try {
      console.log('[FRONTEND] Rozpoczynam skanowanie sieci...');
      const response = await fetch('/api/scan-networks');
      console.log('[FRONTEND] Response status:', response.status);
      
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }
      
      const data = await response.json();
      console.log('[FRONTEND] Otrzymane dane:', data);
      
      if (data.networks && Array.isArray(data.networks)) {
        setNetworks(data.networks);
        console.log(`[FRONTEND] Ustawiono ${data.networks.length} sieci`);
      } else {
        console.error('[FRONTEND] Nieprawidłowy format danych:', data);
        setError('Nieprawidłowy format danych z serwera');
      }
    } catch (err) {
      console.error('[FRONTEND] Błąd skanowania:', err);
      setError(`Nie można zeskanować sieci: ${err.message}`);
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
    // Widok mobilny - od razu pokaz konfiguracje
    if (isMobile) {
      return (
        <div className="App mobile-view">
          <h1>📶 Konfiguracja WiFi</h1>
          <div className="mobile-info">
            <p className="success-message">
              ✓ Połączono z urządzeniem!<br/>
              Wybierz sieć WiFi do połączenia z internetem:
            </p>
          </div>
          <button 
            onClick={scanNetworks} 
            className="mobile-scan-btn"
            style={{ 
              fontSize: '18px',
              padding: '15px 30px',
              margin: '20px 0',
              backgroundColor: '#4CAF50',
              color: 'white',
              border: 'none',
              borderRadius: '8px',
              cursor: 'pointer',
              width: '100%',
              maxWidth: '300px'
            }}
          >
            🔍 Wybierz sieć WiFi
          </button>
          <div className="mobile-device-info">
            <p style={{ fontSize: '12px', color: '#666', marginTop: '20px' }}>
              Sieć: {hotspotInfo.ssid} | Hasło: {hotspotInfo.password}
            </p>
          </div>
        </div>
      );
    }
    
    // Widok kiosk - pokaż QR i instrukcje
    return (
      <div className="App kiosk-view">
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
              <li><strong>Telefonem:</strong> Zeskanuj kod QR</li>
              <li><strong>Ręcznie:</strong> Połącz z siecią <strong>{hotspotInfo.ssid}</strong></li>
              <li>Hasło: <strong>{hotspotInfo.password}</strong></li>
              <li>Otwórz przeglądarkę na <strong>192.168.100.1</strong></li>
            </ol>
          </div>
        </div>
      </div>
    );
  }

  if (mode === 'configuring') {
    const formStyle = isMobile ? {
      padding: '10px',
      maxWidth: '100%'
    } : {};
    
    const selectStyle = isMobile ? {
      fontSize: '16px',
      padding: '12px',
      marginBottom: '15px',
      width: '100%',
      borderRadius: '8px',
      border: '2px solid #ddd'
    } : {};
    
    const inputStyle = isMobile ? {
      fontSize: '16px',
      padding: '12px',
      marginBottom: '15px',
      width: '100%',
      borderRadius: '8px',
      border: '2px solid #ddd'
    } : {};
    
    const buttonStyle = isMobile ? {
      fontSize: '18px',
      padding: '15px 30px',
      width: '100%',
      borderRadius: '8px',
      backgroundColor: isConnecting ? '#ccc' : '#4CAF50',
      color: 'white',
      border: 'none',
      cursor: isConnecting ? 'not-allowed' : 'pointer'
    } : {};
    
    return (
      <>
        {isConnecting && <ConnectingOverlay selectedNetwork={selectedNetwork} />}
        <div className={`App ${isMobile ? 'mobile-view' : 'kiosk-view'}`}>
          <h1>{isMobile ? '📶 Wybierz WiFi' : 'Wybierz sieć WiFi'}</h1>
          {error && <p className="error">{error}</p>}
          {isMobile && (
            <p style={{ fontSize: '14px', color: '#666', marginBottom: '20px' }}>
              Wybierz sieć WiFi i wprowadź hasło aby połączyć urządzenie z internetem:
            </p>
          )}
          <form onSubmit={connectToWifi} style={formStyle}>
            <select 
              value={selectedNetwork} 
              onChange={(e) => setSelectedNetwork(e.target.value)}
              required
              style={selectStyle}
            >
              <option value="">Wybierz sieć</option>
              {networks.map(network => (
                <option key={network.ssid} value={network.ssid}>
                  {isMobile ? 
                    `${network.ssid} (${network.signal}%)` :
                    `${network.ssid} ({network.signal}%)`
                  }
                </option>
              ))}
            </select>
            <input
              type="password"
              placeholder={isMobile ? "Hasło WiFi" : "Hasło WiFi (min. 8 znaków)"}
              value={password}
              onChange={(e) => {
                setPassword(e.target.value);
                if (error && error.includes('Hasło')) {
                  setError('');
                }
              }}
              required
              minLength="8"
              maxLength="63"
              style={inputStyle}
            />
            <button type="submit" disabled={isConnecting} style={buttonStyle}>
              {isConnecting ? (
                <>
                  <span className="spinner"></span>
                  {isMobile ? ' Łączenie...' : 'Łączenie...'}
                </>
              ) : (
                isMobile ? '🔗 Połącz z internetem' : 'Połącz'
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
      <div className={`App ${isMobile ? 'mobile-view' : 'kiosk-view'}`}>
        <h1>{isMobile ? '✓ Połączono!' : 'Połączono z WiFi!'}</h1>
        <p style={isMobile ? { fontSize: '16px', color: '#4CAF50', fontWeight: 'bold' } : {}}>
          {isMobile ? 
            'Urządzenie ma dostęp do internetu 🌐' :
            'Urządzenie jest teraz połączone z internetem.'
          }
        </p>
        {isMobile && (
          <div style={{ margin: '20px 0', padding: '15px', backgroundColor: '#e8f5e8', borderRadius: '8px' }}>
            <p style={{ margin: 0, fontSize: '14px' }}>
              🎉 Konfiguracja zakończona pomyślnie!<br/>
              Możesz teraz zamknąć tę stronę.
            </p>
          </div>
        )}
        <button 
          onClick={resetToHotspot} 
          style={isMobile ? {
            marginTop: '30px',
            fontSize: '16px',
            padding: '12px 24px',
            backgroundColor: '#ff9800',
            color: 'white',
            border: 'none',
            borderRadius: '8px',
            cursor: 'pointer'
          } : {
            marginTop: '20px', 
            background: 'rgba(250, 245, 240, 0.1)', 
            border: '1px solid rgba(250, 245, 240, 0.3)'
          }}
        >
          {isMobile ? '🔄 Zmień sieć' : 'Zmień sieć WiFi'}
        </button>
      </div>
    );
  }

  return null;
}

export default App;
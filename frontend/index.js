import QRCode from "https://cdn.skypack.dev/qrcode";

document.body.innerHTML = `
  <form id="wifi-form">
    <label>SSID: <input name="ssid" required /></label><br/>
    <label>Hasło: <input name="password" required type="password" /></label><br/>
    <button type="submit">Połącz</button>
  </form>
  <canvas id="qrcode"></canvas>
  <div id="status"></div>
`;

document.getElementById("wifi-form").addEventListener("submit", async (e) => {
  e.preventDefault();
  const form = new FormData(e.target);
  const ssid = form.get("ssid");
  const password = form.get("password");
  const wifiString = `WIFI:T:WPA;S:${ssid};P:${password};;`;
  await QRCode.toCanvas(document.getElementById("qrcode"), wifiString);
  const res = await fetch("/connect", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `ssid=${encodeURIComponent(ssid)}&password=${encodeURIComponent(password)}`
  });
  document.getElementById("status").innerText = await res.text();
});

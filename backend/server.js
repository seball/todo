const express = require("express");
const bodyParser = require("body-parser");
const fs = require("fs");
const { exec } = require("child_process");

const app = express();
app.use(bodyParser.urlencoded({ extended: false }));
app.use(express.static("frontend"));

app.post("/connect", (req, res) => {
  const { ssid, password } = req.body;
  const config = `\nnetwork={\n  ssid=\"${ssid}\"\n  psk=\"${password}\"\n}`;
  fs.appendFileSync("/etc/wpa_supplicant/wpa_supplicant.conf", config);
  exec("sudo wpa_cli -i wlan0 reconfigure", (err) => {
    if (err) return res.status(500).send("Błąd połączenia");
    res.send("Połączono z siecią Wi-Fi");
  });
});

app.listen(80, () => console.log("Serwer działa na porcie 80"));

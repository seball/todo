#!/bin/bash
# Czekaj na frontend
sleep 5
chromium-browser --noerrdialogs --disable-infobars --kiosk --start-fullscreen http://localhost:3000

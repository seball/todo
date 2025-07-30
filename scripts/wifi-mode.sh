#!/bin/bash
# Skrypt do przełączania między trybem AP (hotspot) a klientem WiFi

MODE=$1

if [ "$MODE" == "ap" ]; then
    echo "Przełączanie w tryb Access Point..."
    
    # Zatrzymaj klienta WiFi
    sudo systemctl stop wpa_supplicant
    sudo ip link set wlan0 down
    sudo ip addr flush dev wlan0
    sudo ip link set wlan0 up
    
    # Ustaw statyczny adres IP dla AP
    sudo ip addr add 192.168.4.1/24 dev wlan0
    
    # Włącz routing
    sudo sysctl net.ipv4.ip_forward=1
    sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
    sudo iptables -A FORWARD -i wlan0 -o eth0 -j ACCEPT
    sudo iptables -A FORWARD -i eth0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT
    
    echo "Tryb AP aktywny"
    
elif [ "$MODE" == "client" ]; then
    echo "Przełączanie w tryb klienta WiFi..."
    
    # Zatrzymaj AP
    sudo killall hostapd dnsmasq 2>/dev/null || true
    
    # Przywróć konfigurację klienta
    sudo ip addr flush dev wlan0
    sudo systemctl start wpa_supplicant
    
    # Wyczyść reguły iptables
    sudo iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE 2>/dev/null || true
    sudo iptables -D FORWARD -i wlan0 -o eth0 -j ACCEPT 2>/dev/null || true
    sudo iptables -D FORWARD -i eth0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
    
    echo "Tryb klienta aktywny"
    
else
    echo "Użycie: $0 [ap|client]"
    exit 1
fi
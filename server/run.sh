#!/bin/sh

echo ""
echo "SERVER IP ADDRESS"
echo "$(curl -s ifconfig.me):25565"
echo ""

RAM_GB=$(free -g | awk '/^Mem:/{print $2}')
RAM_MB=$((RAM_GB * 1024))
RAM_VAR=$((RAM_MB - 2048))

echo ""
echo "USING ${RAM_VAR} MB RAM"
echo ""

java -Xmx${RAM_VAR}M -Xms${RAM_VAR}M -jar ./forge-1.12.2-14.23.5.2860.jar nogui

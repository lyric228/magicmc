#!/bin/sh

echo ""
echo "SERVER IP ADDRESS"
echo "$(curl -s ifconfig.me):25565"
echo ""

java -Xmx6144M -Xms4096M -jar ./forge-1.12.2-14.23.5.2860.jar nogui

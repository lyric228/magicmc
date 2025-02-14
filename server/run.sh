#!/bin/sh

echo "SERVER IP ADDRESS: $(curl -s ifconfig.me):25565"

TOTAL_MEM=$(free -m | awk '/^Mem:/{m=$2} /^Swap:/{s=$2} END{print m+s}')
RAM_VAR=$((TOTAL_MEM - 8192))

echo -e "\nALLOCATED: ${RAM_VAR}M (Total: ${TOTAL_MEM}M)"

java -Xmx${RAM_VAR}M -Xms${RAM_VAR}M \
-XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 \
-XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC \
-jar ./forge-1.12.2-14.23.5.2860.jar nogui

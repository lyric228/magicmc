#!/bin/sh

echo ""
echo "SERVER IP ADDRESS"
echo "$(curl -s ifconfig.me):25565"
echo ""

TOTAL_MEM=$(free -m | awk '
    /^Mem:/ { mem_total = $2 }
    /^Swap:/ { swap_total = $2 }
    END { print mem_total + swap_total }'
)

RAM_VAR=$((TOTAL_MEM - 8192))

echo ""
echo "AVAILABLE MEMORY (RAM+SWAP): ${TOTAL_MEM} MB"
echo "USING ${RAM_VAR} MB FOR SERVER"
echo ""

java -Xmx${RAM_VAR}M -Xms${RAM_VAR}M \
-XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 \
-XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC \
-jar ./forge-1.12.2-14.23.5.2860.jar nogui

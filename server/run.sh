#!/bin/sh

echo ""
echo "SERVER IP ADDRESS"
echo "$(curl -s ifconfig.me):25565"
echo ""

# Получаем общую RAM + SWAP
TOTAL_MEM=$(free -m | awk '
    /^Mem:/ { mem_total = $2 }
    /^Swap:/ { swap_total = $2 }
    END { print mem_total + swap_total }'
)

RAM_VAR=$((TOTAL_MEM - 4096))

echo ""
echo "AVAILABLE MEMORY (RAM+SWAP): ${TOTAL_MEM} MB"
echo "USING ${RAM_VAR} MB FOR SERVER"
echo ""

java -Xmx${RAM_VAR}M -Xms${RAM_VAR}M -jar ./forge-1.12.2-14.23.5.2860.jar nogui

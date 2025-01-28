#!/bin/sh

echo ""
echo "SERVER IP ADDRESS"
echo "$(curl -s ifconfig.me):25565"
echo ""

# sudo ufw enable
#
# config_file="server.properties"
# external_ip=$(curl -s ifconfig.me)
#
# if [[ -z "$external_ip" ]]; then
#   echo "Не удалось получить внешний IP-адрес."
#   exit 1
# fi
#
# if grep -q "^server-ip=" "$config_file"; then
#   sed -i "s/^server-ip=.*/server-ip=$external_ip/" "$config_file"
#   echo "IP-адрес успешно обновлён: $external_ip"
# else
#   echo "server-ip=$external_ip" >> "$config_file"
#   echo "Строка server-ip добавлена с IP-адресом: $external_ip"
# fi

java -Xmx6144M -Xms4096M -jar ./forge-1.12.2-14.23.5.2860.jar nogui

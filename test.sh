#!/usr/bin/env bash

# 設定虛擬機 ID 和密碼
VMID=100 # 替換為您的虛擬機 ID

# 網路設定
LAN_IP="192.168.2.1"
NET_MASK="255.255.255.0"

# Expect 腳本
expect -c "
spawn qm terminal $VMID

expect \"# \"
send \"\r\"

send \"uci delete network.@device\[0\]\r\"
expect \"# \"
send \"uci set network.wan=interface\r\"
expect \"# \"
send \"uci set network.wan.device=eth0\r\"
expect \"# \"
send \"uci set network.wan.proto=dhcp\r\"
expect \"# \"
send \"uci set network.lan=interface\r\"
expect \"# \"
send \"uci set network.lan.device=br-lan\r\"
expect \"# \"
send \"uci set network.lan.proto=static\r\"
expect \"# \"
send \"uci set network.lan.ipaddr=$LAN_IP\r\"
expect \"# \"
send \"uci set network.lan.netmask=$NET_MASK\r\"
expect \"# \"
send \"uci set network.lan.type=bridge\r\"
expect \"# \"
send \"uci set network.lan.ifname=eth1\r\"
expect \"# \"
send \"uci delete network.wan6\r\"
expect \"# \"
send \"uci commit network\r\"
expect \"# \"
send \"service network restart\r\"
expect \"# \"

# 退出虛擬機終端
send \"exit\r\"
expect eof
"

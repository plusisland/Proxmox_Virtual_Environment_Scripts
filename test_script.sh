#!/usr/bin/env bash
# https://openwrt.org/docs/guide-user/virtualization/qemu#openwrt_in_qemu_x86-64

response=$(curl -s https://openwrt.org)
stableversion=$(echo "$response" | sed -n 's/.*Current stable release - OpenWrt \([0-9.]\+\).*/\1/p' | head -n 1)
URL="https://downloads.openwrt.org/releases/$stableversion/targets/x86/64/openwrt-$stableversion-x86-64-generic-ext4-combined-efi.img.gz"
wget -q --show-progress $URL
VMID=100
VMNAME="OpenWrt"
STORAGEID=$(cat /etc/pve/storage.cfg | grep "content images" -B 3 | awk 'NR==1{print $2}')
CORES=1
MEMORY=256
PCIID="0000:05:00.0"
gunzip openwrt-*.img.gz
qemu-img resize -f raw openwrt-*.imgz 512M
qm create $VMID --name $VMNAME -ostype l26 --machine q35 --bios ovmf --scsihw virtio-scsi-single --cores $CORES --cpu host --memory $MEMORY --net0 virtio,bridge=vmbr0 --net1 virtio,bridge=vmbr1 --onboot 1
qm importdisk $VMID openwrt-*.img $STORAGEID
qm set $VMID --scsi0 $STORAGEID:vm-$VMID-disk-0
qm set $VMID --boot order=scsi0
qm set $VMID --hostpci0 $PCIID,pcie=1
qm start $VMID
sleep 15

IPADDR="192.168.2.1"
NETMASK="255.255.255.0"

# 進入虛擬機的終端並進行設定
qm terminal $VMID << EOF
# 設定 LAN 介面的 IP 地址和子網掩碼
uci delete network.@device[0]
uci set network.wan=interface
uci set network.wan.device=eth0
uci set network.wan.proto=dhcp
uci delete network.lan
uci set network.lan=interface
uci set network.lan.device=eth1
uci set network.lan.proto=static
uci set network.lan.ipaddr='$IPADDR'
uci set network.lan.netmask='$NETMASK'
uci commit network

# 重啟網路服務
/etc/init.d/network restart

# 顯示當前網路配置
ifconfig
EOF

rm -rf openwrt-*.img.gz

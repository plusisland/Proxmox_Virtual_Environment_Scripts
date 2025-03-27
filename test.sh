#!/usr/bin/env bash
# https://openwrt.org/docs/guide-user/virtualization/qemu#openwrt_in_qemu_x86-64
# https://github.com/kjames2001/OpenWRT-PVE-AP-MT7922

# 詢問使用者虛擬機 ID
read -p "請輸入虛擬機 ID (VM_ID): " VM_ID
while [[ -z "$VM_ID" || ! "$VM_ID" =~ ^[0-9]+$ ]]; do
    echo "虛擬機 ID 必須為數字且不能為空。"
    read -p "請輸入虛擬機 ID (VM_ID): " VM_ID
done

VM_NAME="OpenWrt"
CORES=1
MEMORY=256
STORAGE_ID=$(pvesm status --content images | awk 'NR==2{print $1}')

# 檢查 lspci  是否已安裝，若未安裝則安裝
if ! command -v lspci &> /dev/null; then
    echo "lspci 未安裝，正在安裝 pciutils..."
    apt install -y pciutils
fi

# 檢查 lsusb 是否已安裝，若未安裝則安裝
if ! command -v lsusb &> /dev/null; then
    echo "lsusb 未安裝，正在安裝 usbutils..."
    apt install -y usbutils
fi

PCI_ID=$(lspci | grep Network | awk '{print $1}')
USB_ID=$(lsusb | grep -E 'Wireless|Bluetooth' | awk '{print $6}')

# 檢查 vmbr1 是否存在，不存在則提示使用者
if ! grep -q "iface vmbr1 inet" /etc/network/interfaces; then
    echo "vmbr1 網橋不存在。"
    echo "請先在 Proxmox VE 中至少建立 vmbr1 網橋。"
    exit 1
fi

# 詢問使用者路由器管理 IP
read -p "請輸入 OpenWrt 路由器管理 IP (例如: 192.168.2.1): " LAN_IP
while [[ -z "$LAN_IP" ]]; do
    echo "IP 位址不能為空。"
    read -p "請輸入 OpenWrt 路由器管理 IP (例如: 192.168.2.1): " LAN_IP
done
# 詢問使用者路由器管理 Netmask
read -p "請輸入 Netmask (例如: 255.255.255.0): " NET_MASK
while [[ -z "$NET_MASK" ]]; do
    echo "Netmask 不能為空。"
    read -p "請輸入 Netmask (例如: 255.255.255.0): " NET_MASK
done

# 取得 OpenWrt 的最新穩定版本
response=$(curl -s https://openwrt.org)
stableversion=$(echo "$response" | sed -n 's/.*Current stable release - OpenWrt \([0-9.]\+\).*/\1/p' | head -n 1)
# 下載 OpenWrt 映像的 URL
URL="https://downloads.openwrt.org/releases/$stableversion/targets/x86/64/openwrt-$stableversion-x86-64-generic-ext4-combined-efi.img.gz"
# 下載 OpenWrt 映像檔
wget -q --show-progress $URL

# 解壓並調整磁碟映像大小
gunzip openwrt-*.img.gz
qemu-img resize -f raw openwrt-*.img 128M

# 安裝 parted
if ! command -v parted &> /dev/null; then
    echo "parted 未安装，正在安装..."
    apt install -y parted
fi

# 取得未使用磁碟裝置位置
loop_device=$(losetup -f)
# 掛載映像
losetup $loop_device openwrt-*.img
# 擴展第二磁區
parted -f -s "$loop_device" resizepart 2 100%
# 擴展檔案系統
resize2fs ${loop_device}p2
# 解除掛載磁碟
losetup -d $loop_device

# 創建虛擬機
qm create $VM_ID \
  --name $VM_NAME \
  --onboot 1 \
  --ostype l26 \
  --machine q35 \
  --bios ovmf \
  --efidisk0 $STORAGE_ID:0 \
  --scsihw virtio-scsi-single \
  --cores $CORES \
  --cpu host \
  --memory $MEMORY \
  --net0 virtio,bridge=vmbr0 \
  --net1 virtio,bridge=vmbr1 \
  --serial0 socket

# 將磁碟映像匯入 Proxmox 儲存空間
qm importdisk $VM_ID openwrt-*.img $STORAGE_ID
qm set $VM_ID \
  --scsi0 $STORAGE_ID:vm-$VM_ID-disk-1 \
  --boot order=scsi0 \
  --hostpci0 $PCI_ID,pcie=1 \
  --usb0 host=$USB_ID
  
# 清理下載的 OpenWrt 映像文件
rm -rf openwrt-*.img

# 啟動虛擬機
qm start $VM_ID

# 等待虛擬機開機完成
echo "等待虛擬機開機完成"
ipk_url=$(curl -s https://api.github.com/repos/jerrykuku/luci-theme-argon/releases | grep '"browser_download_url":' | grep 'luci-theme-argon.*_all\.ipk' | head -n 1 | sed -n 's/.*"browser_download_url": "\([^"]*\)".*/\1/p')
sleep 20

# Expect 腳本
expect -c "
spawn qm terminal $VM_ID
expect \"starting serial terminal\"
send \"\r\"
expect \"# \"
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
expect \"eth0\"
send \"\r\"
send \"uci set dhcp.lan.interface=lan\r\"
expect \"# \"
send \"uci set dhcp.lan=dhcp\r\"
expect \"# \"
send \"uci set dhcp.lan.start=100\r\"
expect \"# \"
send \"uci set dhcp.lan.limit=100\r\"
expect \"# \"
send \"uci set dhcp.lan.leasetime=12h\r\"
expect \"# \"
send \"uci commit dhcp\r\"
expect \"# \"
send \"service dnsmasq restart\r\"
expect \"# \"
send \"opkg update\r\"
expect \"# \"
send \"opkg install luci-i18n-base-zh-tw luci-compat luci-lib-ipkg\r\"
expect \"# \"
send \"wget -O luci-theme-argon.ipk $ipk_url\r\"
expect \"# \"
send \"opkg install luci-theme-argon.ipk\r\"
expect \"# \"
send \"rm -rf luci-theme-argon.ipk\r\"
expect \"# \"
send \"opkg install pciutils usbutils acpid qemu-ga\r\"
expect \"Configuring qemu-ga.\"

set intel 0
set mediatek 0

send \"lspci\r\"
expect {
  *AX210* { set intel 1 }
  *MT7922* { set mediatek 1 }
  timeout {}
  eof {}
}

if { \$intel == 1 } {
send \"\r\"
expect \"# \"
send \"opkg install kmod-iwlwifi iwlwifi-firmware-ax210 wpad-openssl kmod-usb2-pci bluez-daemon\r\"
expect \"Configuring bluez-daemon.\"
send \"\r\"
expect \"# \"
send \"uci set wireless.radio0.disabled=0\r\"
expect \"# \"
send \"uci set wireless.radio0.channel=6\r\"
expect \"# \"
send \"uci set wireless.radio0.band=\'2g\'\r\"
expect \"# \"
send \"uci set wireless.radio0.htmode=HE40\r\"
expect \"# \"
send \"uci set wireless.radio0.country=TW\r\"
expect \"# \"
send \"uci set wireless.default_radio0.network=lan\r\"
expect \"# \"
send \"uci set wireless.default_radio0.mode=ap\r\"
expect \"# \"
send \"uci set wireless.default_radio0.ssid=OpenWrt\r\"
expect \"# \"
send \"uci set wireless.default_radio0.encryption=none\r\"
expect \"# \"
send \"sed -i '/exit 0/i (sleep 10; wifi; service bluetoothd restart) &' /etc/rc.local\r\"
expect \"# \"
send \"uci commit wireless\r\"
expect \"# \"
send \"wifi\r\"
expect \"# \"
send \"reboot\r\"
} elseif { \$mediatek == 1 } {
send \"\r\"
expect \"# \"
send \"opkg install kmod-mt7921e kmod-mt7922-firmware wpad-openssl mt7922bt-firmware kmod-usb2-pci bluez-daemon\r\"
expect \"Configuring bluez-daemon.\"
send \"\r\"
expect \"# \"
send \"uci set wireless.radio0.disabled=0\r\"
expect \"# \"
send \"uci set wireless.radio0.channel=149\r\"
expect \"# \"
send \"uci set wireless.radio0.band=\'5g\'\r\"
expect \"# \"
send \"uci set wireless.radio0.htmode=HE80\r\"
expect \"# \"
send \"uci set wireless.radio0.country=TW\r\"
expect \"# \"
send \"uci set wireless.default_radio0.network=lan\r\"
expect \"# \"
send \"uci set wireless.default_radio0.mode=ap\r\"
expect \"# \"
send \"uci set wireless.default_radio0.ssid=OpenWrt\r\"
expect \"# \"
send \"uci set wireless.default_radio0.encryption=none\r\"
expect \"# \"
send \"sed -i '/exit 0/i (sleep 10; wifi; service bluetoothd restart) &' /etc/rc.local\r\"
expect \"# \"
send \"uci commit wireless\r\"
expect \"# \"
send \"wifi\r\"
expect \"# \"
send \"reboot\r\"
}
expect eof
"

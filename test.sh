#!/usr/bin/env bash
# https://openwrt.org/docs/guide-user/virtualization/qemu#openwrt_in_qemu_x86-64
# https://github.com/kjames2001/OpenWRT-PVE-AP-MT7922

# 詢問使用者虛擬機 ID
read -p "請輸入虛擬機 ID (VM_ID): " VM_ID
while [[ -z "$VM_ID" || ! "$VM_ID" =~ ^[0-9]+$ ]]; do
    echo "虛擬機 ID 必須為數字且不能為空。"
    read -p "請輸入虛擬機 ID (VM_ID): " VM_ID
done

VM_NAME=OpenWrt
VM_CORE=1
VM_MEM=256
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
RESPONSE=$(curl -s https://openwrt.org)
STABLEVERSION=$(echo "$RESPONSE" | sed -n 's/.*Current stable release - OpenWrt \([0-9.]\+\).*/\1/p' | head -n 1)
# 下載 OpenWrt 映像的 URL
IMG_URL="https://downloads.openwrt.org/releases/$STABLEVERSION/targets/x86/64/openwrt-$STABLEVERSION-x86-64-generic-ext4-combined-efi.img.gz"
# 下載 OpenWrt 映像檔
wget -q --show-progress $IMG_URL

# 解壓並調整磁碟映像大小
gunzip openwrt-*.img.gz
qemu-img resize -f raw openwrt-*.img 128M

# 安裝 parted
if ! command -v parted &> /dev/null; then
    echo "parted 未安装，正在安装..."
    apt install -y parted
fi

# 取得未使用磁碟裝置位置
LOOP_DEVICE=$(losetup -f)
# 掛載映像
losetup $LOOP_DEVICE openwrt-*.img
# 擴展第二磁區
parted -f -s "$LOOP_DEVICE" resizepart 2 100%
# 擴展檔案系統
resize2fs ${LOOP_DEVICE}p2
# 解除掛載磁碟
losetup -d $LOOP_DEVICE

# 創建虛擬機
qm create $VM_ID \
  --name $VM_NAME \
  --onboot 1 \
  --ostype l26 \
  --machine q35 \
  --bios ovmf \
  --efidisk0 $STORAGE_ID:0 \
  --scsihw virtio-scsi-single \
  --cores $VM_CORE \
  --cpu host \
  --memory $VM_MEM \
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
sleep 30

# OpenWrt Argon Theme
IPK_URL1=$(curl -s https://api.github.com/repos/jerrykuku/luci-theme-argon/releases | grep '"browser_download_url":' | grep 'luci-theme-argon.*_all\.ipk' | head -n 1 | sed -n 's/.*"browser_download_url": "\([^"]*\)".*/\1/p')
# OpenWrt Argon Theme Config Plugin
IPK_URL2=$(curl -s https://api.github.com/repos/jerrykuku/luci-app-argon-config/releases | grep '"browser_download_url":' | grep 'luci-app-argon-config_.*_all\.ipk' | head -n 1 | sed -n 's/.*"browser_download_url": "\([^"]*\)".*/\1/p')

if lspci | grep -q "AX210"; then
  echo "偵測到 Intel AX210 網卡，安裝驅動..."
  DRIVER_FIREWARE="kmod-iwlwifi iwlwifi-firmware-ax210"
  CHANNEL=6
  BAND='2g'
  HTMODE=HE40
elif lspci | grep -q "MT7922"; then
  echo "偵測到 MediaTek MT7922 網卡，安裝驅動..."
  DRIVER_FIREWARE="kmod-mt7921e kmod-mt7922-firmware mt7922bt-firmware"
  CHANNEL=149
  BAND='5g'
  HTMODE=HE80
else
  echo "未偵測到 Intel AX210 或 MediaTek MT7922 網卡，跳過驅動安裝。"
  DRIVER_FIREWARE=
  CHANNEL=
  BAND=
  HTMODE=
fi

expect -c "
set timeout -1
spawn qm terminal $VM_ID
expect \"starting serial terminal on interface serial0 (press Ctrl+O to exit)\"
send \"\r\"
expect \"# \"
send \"uci delete network.@device\[0\]\r\"
send \"uci set network.wan=interface\r\"
send \"uci set network.wan.device=eth0\r\"
send \"uci set network.wan.proto=dhcp\r\"
send \"uci set network.lan=interface\r\"
send \"uci set network.lan.device=br-lan\r\"
send \"uci set network.lan.proto=static\r\"
send \"uci set network.lan.ipaddr=$LAN_IP\r\"
send \"uci set network.lan.netmask=$NET_MASK\r\"
send \"uci set network.lan.type=bridge\r\"
send \"uci set network.lan.ifname=eth1\r\"
send \"uci delete network.wan6\r\"
send \"uci commit network\r\"
send \"service network restart\r\"
expect \"8021q: adding VLAN 0 to HW filter on device eth0\"
send \"\r\"
expect \"# \"
send \"uci set dhcp.lan.interface=lan\r\"
send \"uci set dhcp.lan=dhcp\r\"
send \"uci set dhcp.lan.start=100\r\"
send \"uci set dhcp.lan.limit=100\r\"
send \"uci set dhcp.lan.leasetime=24h\r\"
send \"uci commit dhcp\r\"
send \"service dnsmasq restart\r\"
expect \"udhcpc: no lease, failing\"
send \"opkg update\r\"
expect \"# \"
send \"opkg install luci-i18n-base-zh-tw luci-compat luci-lib-ipkg\r\"
expect \"Configuring luci-compat.\"
send \"wget -O luci-theme-argon.ipk $IPK_URL1\r\"
expect \"Download completed\"
send \"opkg install luci-theme-argon.ipk\r\"
expect \"Configuring luci-theme-argon.\"
send \"rm -rf luci-theme-argon.ipk\r\"
expect \"# \"
send \"wget -O luci-app-argon-config.ipk $IPK_URL2\r\"
expect \"Download completed\"
send \"opkg install luci-app-argon-config.ipk\r\"
expect \"Configuring luci-app-argon-config.\"
send \"rm -rf luci-app-argon-config.ipk\r\"
expect \"# \"
send \"opkg install pciutils usbutils acpid qemu-ga\r\"
expect \"Configuring qemu-ga.\"
send \"\r\"
send \"opkg install $DRIVER_FIREWARE wpad-openssl kmod-usb2-pci bluez-daemon\r\"
expect \"Configuring bluez-daemon.\"
expect \"Bluetooth: MGMT ver\"
sleep 5
send \"\r\"
expect \"# \"
send \"uci set wireless.radio0.disabled=0\r\"
expect \"# \"
send \"uci set wireless.radio0.channel=$CHANNEL\r\"
expect \"# \"
send \"uci set wireless.radio0.band=$BAND\r\"
expect \"# \"
send \"uci set wireless.radio0.htmode=$HTMODE\r\"
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
exit
"
echo "設定完成!"

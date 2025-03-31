#!/usr/bin/env bash
# https://docs.opnsense.org/manual/virtuals.html

# 詢問使用者虛擬機 ID
read -p "請輸入虛擬機 ID (VM_ID): " VM_ID
while [[ -z "$VM_ID" || ! "$VM_ID" =~ ^[0-9]+$ ]]; do
    echo "虛擬機 ID 必須為數字且不能為空。"
    read -p "請輸入虛擬機 ID (VM_ID): " VM_ID
done

VM_NAME=OPNsense
VM_CORE=1
VM_MEM=1024
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
read -p "請輸入 OpenWrt 路由器管理 IP (例如: 192.168.1.1): " LAN_IP
while [[ -z "$LAN_IP" ]]; do
    echo "IP 位址不能為空。"
    read -p "請輸入 OpenWrt 路由器管理 IP (例如: 192.168.1.1): " LAN_IP
done

# 詢問使用者路由器管理 Netmask
read -p "請輸入 Netmask (例如: 255.255.255.0): " NET_MASK
while [[ -z "$NET_MASK" ]]; do
    echo "Netmask 不能為空。"
    read -p "請輸入 Netmask (例如: 255.255.255.0): " NET_MASK
done

# 取得 OPNsense 的最新穩定版本
RESPONSE=$(curl -s https://mirror.ntct.edu.tw/opnsense/releases/mirror/)
STABLEVERSION=$(echo "$RESPONSE" | sed -n 's/.*OPNsense-\([0-9.]\+\).*/\1/p' | head -n 1)
# 下載 OPNsense 映像的 URL
IMG_URL="https://mirror.ntct.edu.tw/opnsense/releases/mirror/OPNsense-$STABLEVERSION-serial-amd64.img.bz2"
# 下載 OPNsense 映像檔
wget -q --show-progress $IMG_URL

# 解壓
bzip2 -d OPNsense-*.img.bz2

# 創建虛擬機
qm create $VM_ID \
  --name $VM_NAME \
  --onboot 1 \
  --ostype other \
  --machine q35 \
  --bios ovmf \
  --efidisk0 $STORAGE_ID:0 \
  --scsihw virtio-scsi-single \
  --scsi0 $STORAGE_ID:8 \
  --cores $VM_CORE \
  --cpu host \
  --memory $VM_MEM \
  --net0 virtio,bridge=vmbr0 \
  --net1 virtio,bridge=vmbr1 \
  --serial0 socket

# 將磁碟映像匯入 Proxmox 儲存空間
qm importdisk $VM_ID OPNsense-*.img $STORAGE_ID
qm set $VM_ID \
  --scsi1 $STORAGE_ID:vm-$VM_ID-disk-2 \
  --boot order=scsi1 \
  --hostpci0 $PCI_ID,pcie=1 \
  --usb0 host=$USB_ID
  
# 清理下載的 OPNsense 映像文件
rm -rf OPNsense-*.img

# 啟動虛擬機
qm start $VM_ID

# 等待虛擬機開機完成
echo "等待虛擬機開機完成"
sleep 30

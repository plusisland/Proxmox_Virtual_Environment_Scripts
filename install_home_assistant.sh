#!/usr/bin/env bash
# https://www.home-assistant.io/installation/alternative
# https://community.home-assistant.io/t/how-to-install-custom-wifi-drivers/689637

# 詢問使用者虛擬機 ID
read -p "請輸入虛擬機 ID (VM_ID): " VM_ID
while [[ -z "$VM_ID" || ! "$VM_ID" =~ ^[0-9]+$ ]]; do
  echo "虛擬機 ID 必須為數字且不能為空。"
  read -p "請輸入虛擬機 ID (VM_ID): " VM_ID
done

VM_NAME=Home-Assistant
VM_CORE=2
VM_MEM=2048
STORAGE_ID=$(pvesm status --content images | awk 'NR==2{print $1}')

# 下載 Home Assistant 映像的 URL
IMG_URL=$(curl -s https://api.github.com/repos/home-assistant/operating-system/releases/latest | grep '"browser_download_url":' | grep 'haos_ova-.*\.qcow2\.xz' | head -n 1 | sed -n 's/.*"browser_download_url": "\([^"]*\)".*/\1/p')

# 下載 Home Assistant 映像檔
wget -q --show-progress $IMG_URL

# 解壓並調整磁碟映像大小
xz -d haos_ova-*.qcow2.xz

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
  --serial0 socket

# 將磁碟映像匯入 Proxmox 儲存空間
qm importdisk $VM_ID haos_ova-*.qcow2 $STORAGE_ID

qm set $VM_ID \
  --scsi0 $STORAGE_ID:vm-$VM_ID-disk-1 \
  --boot order=scsi0

# 清理下載的 Home Assistant 映像文件
rm -rf haos_ova-*.qcow2

# 啟動虛擬機
qm start $VM_ID

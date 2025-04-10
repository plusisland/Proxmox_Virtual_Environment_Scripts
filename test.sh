#!/usr/bin/env bash
# https://nextcloud.com/install/#aio

# 詢問使用者虛擬機 ID
read -p "請輸入虛擬機 ID (VM_ID): " VM_ID
while [[ -z "$VM_ID" || ! "$VM_ID" =~ ^[0-9]+$ ]]; do
  echo "虛擬機 ID 必須為數字且不能為空。"
  read -p "請輸入虛擬機 ID (VM_ID): " VM_ID
done

VM_NAME=Nextcloud
VM_CORE=2
VM_MEM=2048
STORAGE_ID=$(pvesm status --content images | awk 'NR==2{print $1}')

# 下載 Nextcloud 映像檔
wget -q --show-progress https://download.nextcloud.com/aio-vm/Nextcloud-AIO.ova

# 解壓並調整磁碟映像大小
tar -xvf Nextcloud-AIO.ova

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
qm importdisk $VM_ID Nextcloud-AIO.vmdk $STORAGE_ID

qm set $VM_ID \
  --scsi0 $STORAGE_ID:vm-$VM_ID-disk-1 \
  --boot order=scsi0

# 清理下載的 Nextcloud 映像文件
rm -rf Nextcloud-AIO-*

# 啟動虛擬機
qm start $VM_ID

#!/usr/bin/env bash
# https://help.mikrotik.com/docs/spaces/ROS/pages/48660553/CHR+ProxMox+installation
# https://help.mikrotik.com/docs/spaces/ROS/pages/328151/First+Time+Configuration#FirstTimeConfiguration-ConfiguringIPAccess

# 詢問使用者虛擬機 ID
read -p "請輸入虛擬機 ID (VM_ID): " VM_ID
while [[ -z "$VM_ID" || ! "$VM_ID" =~ ^[0-9]+$ ]]; do
    echo "虛擬機 ID 必須為數字且不能為空。"
    read -p "請輸入虛擬機 ID (VM_ID): " VM_ID
done

# 詢問使用者設定管理密碼
read -p "請輸入管理密碼 PW (VM_PW): " VM_PW
while [[ -z "$VM_PW" ]]; do
    echo "虛擬機 PW 不能為空。"
    read -p "請輸入虛擬機 PW (VM_PW): " VM_PW
done

VM_NAME=MikroTik
VM_CORE=1
VM_MEM=256
STORAGE_ID=$(pvesm status --content images | awk 'NR==2{print $1}')

# 檢查 vmbr1 是否存在，不存在則提示使用者
if ! grep -q "iface vmbr1 inet" /etc/network/interfaces; then
    echo "vmbr1 網橋不存在。"
    echo "請先在 Proxmox VE 中至少建立 vmbr1 網橋。"
    exit 1
fi

# 詢問使用者路由器管理 IP
read -p "請輸入 OpenWrt 路由器管理 IP (例如: 192.168.88.1): " LAN_IP
while [[ -z "$LAN_IP" ]]; do
    echo "IP 位址不能為空。"
    read -p "請輸入 OpenWrt 路由器管理 IP (例如: 192.168.88.1): " LAN_IP
done

# 檢查 zip 是否已安裝，若未安裝則安裝
if ! command -v zip &> /dev/null; then
    echo "zip 未安裝，正在安裝 zip..."
    apt install -y zip
fi

# 取得 MikroTik 的最新穩定版本
RESPONSE=$(curl -s https://download.mikrotik.com/routeros/latest-stable.rss)
STABLEVERSION=$(echo "$RESPONSE" | sed -n 's/.*>RouterOS \([0-9.]\+\).*/\1/p' | head -n 1)
# 下載 MikroTik 映像的 URL
IMG_URL="https://download.mikrotik.com/routeros/$STABLEVERSION/chr-$STABLEVERSION.img.zip"
# 下載 MikroTik 映像檔
wget -q --show-progress $IMG_URL

# 解壓並調整磁碟映像大小
unzip chr-*.img.zip
qemu-img resize -f raw chr-*.img 128M

# 創建虛擬機
qm create $VM_ID \
  --name $VM_NAME \
  --onboot 1 \
  --ostype l26 \
  --scsihw virtio-scsi-single \
  --agent 1 \
  --cores $VM_CORE \
  --cpu host \
  --memory $VM_MEM \
  --net0 virtio,bridge=vmbr0 \
  --net1 virtio,bridge=vmbr1 \
  --serial0 socket

# 將磁碟映像匯入 Proxmox 儲存空間
qm importdisk $VM_ID chr-*.img $STORAGE_ID
qm set $VM_ID \
  --scsi0 $STORAGE_ID:vm-$VM_ID-disk-0 \
  --boot order=scsi0
  
# 清理下載的 MikroTik 映像文件
rm -rf chr-*.img

# 啟動虛擬機
qm start $VM_ID

# 等待虛擬機開機完成
echo "等待虛擬機開機完成"
sleep 5

expect -c "
set timeout -1
spawn qm terminal $VM_ID
expect \"starting serial terminal on interface serial0 (press Ctrl+O to exit)\"
send \"\r\"
expect \"MikroTik Login: \"
send \"admin\r\"
expect \"Password: \"
send \"\r\"
expect \"Do you want to see the software license?\"
send \"n\r\"
expect \"new password> \"
send \"$VM_PW\r\"
expect \"repeat new password> \"
send \"$VM_PW\r\"
expect \"MikroTik\"
send \"/interface bridge add name=br-lan\r\"
expect \"MikroTik\"
send \"/interface bridge port add interface=ether2 bridge=br-lan\r\"
expect \"MikroTik\"
send \"/ip address add address=$LAN_IP/24 interface=br-lan\r\"
expect \"MikroTik\"
send \"/ip dhcp-server/ setup\r\"
expect \"dhcp server interface: \"
send \"br-lan\r\"
expect \"dhcp address space: \"
send \"\r\"
expect \"gateway for dhcp network: \"
send \"\r\"
expect \"addresses to give out: \"
send \"\r\"
expect \"dns servers: \"
send \"\r\"
expect \"lease time: \"
send \"\r\"
expect \"MikroTik\"
send \"/system shutdown\r\"
expect \"Shutdown, yes?\"
send \"y\r\"
exit
"
echo "MikroTik 設定完成!關閉虛擬機"

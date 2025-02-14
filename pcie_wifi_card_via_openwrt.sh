#!/usr/bin/env bash
# https://openwrt.org/docs/guide-user/virtualization/qemu?s[]=proxmox#openwrt_in_qemu_x86-64

# ----- 使用者可設定變數 -----
DEFAULT_VMID=100
DEFAULT_DISK_SIZE=512
DEFAULT_CPU_COUNT=1
DEFAULT_RAM_SIZE=256
DEFAULT_LAN_IP="192.168.1.1"
DEFAULT_BRIDGE_IFACE="enp1s1"
# VMBR1_IP="192.168.1.2/24"  移除 VMBR1_IP 變數
STORAGE_ID=$(grep -oP '^(lvmthin|zfspool|dir): \K[^:]+' /etc/pve/storage.cfg | head -n 1)

# ----- 函式定義 -----
error_exit() {
    echo "錯誤: $1"
    exit 1
}

check_command_status() {
    if [ $1 -ne 0 ]; then
        error_exit "$2 指令執行失敗！"
    }
}

# ----- 檢查 root 權限 -----
if [ "$(id -u)" != "0" ]; then
    error_exit "請使用 root 權限執行此腳本！"
fi

# ----- 詢問使用者是否自訂網路設定 -----
read -p "是否自訂橋接介面卡名稱？ (y/N，預設 N): " CUSTOM_NETWORK # 移除 vmbr1 IP 自訂選項，僅保留橋接介面自訂
if [[ "$CUSTOM_NETWORK" =~ ^[yY] ]]; then
    # 移除 VMBR1_IP 自訂選項
    read -p "請輸入要橋接的網路介面卡名稱 (例如 enp1s1): " BRIDGE_IFACE_CUSTOM
    if [ -n "$BRIDGE_IFACE_CUSTOM" ]; then
        DEFAULT_BRIDGE_IFACE="$BRIDGE_IFACE_CUSTOM"
    fi
fi

# ----- 詢問使用者輸入 -----
read -p "請輸入 VM ID（預設 ${DEFAULT_VMID}）: " VMID
VMID=${VMID:-$DEFAULT_VMID}
if ! [[ "$VMID" =~ ^[0-9]+$ ]]; then
    error_exit "VM ID 必須是數字！"
fi

read -p "請輸入虛擬機名稱: " VM_NAME
if [ -z "$VM_NAME" ]; then
    error_exit "虛擬機名稱不能為空！"
fi

read -p "請輸入 CPU 數量（預設 ${DEFAULT_CPU_COUNT}）: " CPU_COUNT
CPU_COUNT=${CPU_COUNT:-$DEFAULT_CPU_COUNT}
if ! [[ "$CPU_COUNT" =~ ^[0-9]+$ ]]; then
    error_exit "CPU 數量必須是數字！"
fi

read -p "請輸入 RAM 大小（MB，預設 ${DEFAULT_RAM_SIZE}MB）: " RAM_SIZE
RAM_SIZE=${RAM_SIZE:-$DEFAULT_RAM_SIZE}
if ! [[ "$RAM_SIZE" =~ ^[0-9]+$ ]]; then
    error_exit "RAM 大小必須是數字！"
fi

read -p "請輸入 OpenWRT 磁碟大小（MB，預設 ${DEFAULT_DISK_SIZE}MB）: " DISK_SIZE
DISK_SIZE=${DISK_SIZE:-$DEFAULT_DISK_SIZE}
if ! [[ "$DISK_SIZE" =~ ^[0-9]+$ ]]; then
    error_exit "磁碟大小必須是數字！"
fi

read -p "請輸入 LAN IP（預設 ${DEFAULT_LAN_IP}）: " LAN_IP
LAN_IP=${LAN_IP:-$DEFAULT_LAN_IP}

BRIDGE_IFACE="$DEFAULT_BRIDGE_IFACE" # 確保橋接介面名稱使用變數

# ----- 檢查並建立 vmbr1 -----
if ! ip link show vmbr1 &>/dev/null; then
    echo "建立 vmbr1 橋接..."
    echo -e "\nauto vmbr1\niface vmbr1 inet manual\n  bridge-ports $BRIDGE_IFACE\n  bridge-stp off\n  bridge-fd 0" >> /etc/network/interfaces # 修改為 inet manual，移除 address 設定
    ifup vmbr1
    check_command_status $? "ifup vmbr1"
else
    echo "vmbr1 已存在，跳過建立步驟。"
fi

# ----- 取得 OpenWRT 最新穩定版 -----
RELEASES_URL="https://downloads.openwrt.org/releases/"
STABLE_VERSION=$(curl -s "$RELEASES_URL" | grep -oP 'href="\K[0-9]+\.[0-9]+\.[0-9]+/' | tr -d '/' | head -n 1)
if [ -z "$STABLE_VERSION" ]; then
    error_exit "無法取得 OpenWRT 最新穩定版本號！"
fi

URL="https://downloads.openwrt.org/releases/$STABLE_VERSION/targets/x86/64/openwrt-$STABLE_VERSION-x86-64-generic-ext4-combined-efi.img.gz"
echo "下載 OpenWRT $STABLE_VERSION EFI IMG..."
wget -q --show-progress "$URL" || error_exit "下載 OpenWRT 失敗！"

gunzip -f "openwrt-$STABLE_VERSION-x86-64-generic-ext4-combined-efi.img.gz"
IMG_FILE="openwrt-$STABLE_VERSION-x86-64-generic-ext4-combined-efi.img"

# ----- 調整映像大小 -----
echo "調整映像檔大小為 ${DISK_SIZE}MB..."
qemu-img resize -f raw "$IMG_FILE" "${DISK_SIZE}M"
check_command_status $? "qemu-img resize"

# ----- 建立虛擬機 -----
echo "建立虛擬機..."
qm create "$VMID" --name "$VM_NAME" --onboot 1 --ostype l26 --machine q35 --bios ovmf --memory "$RAM_SIZE" --cores "$CPU_COUNT" --cpu host --net0 virtio,bridge=vmbr0 --net1 virtio,bridge=vmbr1
check_command_status $? "qm create"

# ----- 匯入磁碟 -----
echo "匯入磁碟..."
qm importdisk "$VMID" "$IMG_FILE" "$STORAGE_ID" --format raw
check_command_status $? "qm importdisk"
qm set "$VMID" --scsihw virtio-scsi-single --virtio0 "$STORAGE_ID:vm-$VMID-disk-0"
check_command_status $? "qm set --scsihw virtio-scsi-single --virtio0"
echo "磁碟匯入完成。"

# ----- 啟動 VM -----
echo "啟動虛擬機..."
qm start "$VMID"
check_command_status $? "qm start"
echo "虛擬機已啟動，VM ID: $VMID。"

# ----- 設定 OpenWRT 網路與安裝套件 (使用 qm terminal 並加入錯誤檢查) -----
echo "設定 OpenWRT 網路與安裝套件..."

# 定義要安裝的套件列表
packages="luci-i18n-base-zh-tw pciutils kmod-mt7921e mt7922bt-firmware kmod-mt7922-firmware wpa-supplicant hostapd"

# 使用 qm terminal 執行指令，並檢查錯誤
execute_remote_command() {
    local command="$1"
    local error_message="$2"
    local result
    result=$(qm terminal "$VMID" --noecho --command "$command ; echo \$?") 2>/dev/null # 忽略 qm terminal 的提示訊息
    remote_exit_code=$(echo "$result" | tail -n 1) # 取得遠端指令的 exit code
    if ! [[ "$remote_exit_code" =~ ^[0-9]+$ ]]; then # 檢查 exit code 是否為數字
        error_exit "執行遠端指令時發生錯誤，無法取得 exit code：$error_message"
    fi
    check_command_status "$remote_exit_code" "$error_message"
}

# 設定 LAN IP
execute_remote_command "uci set network.lan.ipaddr='$LAN_IP' && uci commit network && /etc/init.d/network restart" "設定 LAN IP 位址失敗"

# 更新 opkg
execute_remote_command "opkg update" "更新 opkg 失敗"

# 迴圈安裝套件
for pkg in $packages; do
    execute_remote_command "opkg install $pkg" "安裝套件 $pkg 失敗"
done

echo "OpenWRT 基本設定與套件安裝完成。"

# ----- 輸出完成訊息 -----
echo "--------------------------------------------------"
echo "OpenWRT 虛擬機建立完成！"
echo "VM ID: $VMID"
echo "虛擬機名稱: $VM_NAME"
echo "LAN IP 位址: $LAN_IP"
echo "--------------------------------------------------"
echo "請手動設定 PCI passthrough，並將 m.2 Wi-Fi 卡直通給 VM ID $VMID。"
echo "OpenWRT Web 介面: http://$LAN_IP"

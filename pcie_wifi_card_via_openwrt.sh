#!/usr/bin/env bash
# https://openwrt.org/docs/guide-user/virtualization/qemu?s[]=proxmox#openwrt_in_qemu_x86-64

# ----- 使用者可設定變數 (預設值) -----
DEFAULT_VMID=100
DEFAULT_DISK_SIZE_MB=512
DEFAULT_CPU_COUNT=1
DEFAULT_RAM_SIZE_MB=256
DEFAULT_LAN_IP="192.168.1.1"
DEFAULT_BRIDGE_IFACE="enp1s1" # 預設橋接介面名稱
STORAGE_ID=$(grep -oP '^(lvmthin|zfspool): \K[^:]+' /etc/pve/storage.cfg | head -n 1) # 自動取得 Storage ID，優先使用 lvmthin 或 zfspool

# ----- 函式定義 -----

error_exit() {
    echo "錯誤: $1"
    exit 1
}

check_command_status() {
    if [ $? -ne 0 ]; then
        error_exit "$1 指令執行失敗！"
    fi
}

check_command_exists() {
    if ! command -v "$1" &> /dev/null; then
        error_exit "缺少必要的指令：$1。請確認是否已安裝。"
    fi
}

is_valid_ip() {
    local ip="$1"
    if [[ "$ip" =~ ^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$ ]]; then
        return 0 # Valid IP
    else
        return 1 # Invalid IP
    fi
}

# ----- 檢查 root 權限 -----
if [ "$(id -u)" != "0" ]; then
    error_exit "請使用 root 權限執行此腳本！"
fi

# ----- 檢查必要指令是否存在 -----
COMMANDS=("curl" "wget" "gunzip" "qm" "grep" "ip" "ifup" "ifdown")
for cmd in "${COMMANDS[@]}"; do
    check_command_exists "$cmd"
done

# ----- 詢問使用者輸入 (若未設定預設值) -----
read -p "請輸入 VM ID（預設 ${DEFAULT_VMID}）: " VMID
VMID=${VMID:-$DEFAULT_VMID}
if ! [[ "$VMID" =~ ^[0-9]+$ ]]; then
    error_exit "VM ID 必須是數字！"
fi

# 檢查 VM ID 是否已存在
if qm list | grep -q "^$VMID "; then
    error_exit "VM ID $VMID 已存在！請選擇其他 VM ID。"
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

read -p "請輸入 RAM 大小（MB，預設 ${DEFAULT_RAM_SIZE_MB}MB）: " RAM_SIZE_MB
RAM_SIZE_MB=${RAM_SIZE_MB:-$DEFAULT_RAM_SIZE_MB}
if ! [[ "$RAM_SIZE_MB" =~ ^[0-9]+$ ]]; then
    error_exit "RAM 大小必須是數字！"
fi

read -p "請輸入 OpenWRT 磁碟大小（MB，預設 ${DEFAULT_DISK_SIZE_MB}MB）: " DISK_SIZE_MB
DISK_SIZE_MB=${DISK_SIZE_MB:-$DEFAULT_DISK_SIZE_MB}
if ! [[ "$DISK_SIZE_MB" =~ ^[0-9]+$ ]]; then
    error_exit "磁碟大小必須是數字！"
fi

read -p "請輸入 LAN IP（預設 ${DEFAULT_LAN_IP}）: " LAN_IP
LAN_IP=${LAN_IP:-$DEFAULT_LAN_IP}
if ! is_valid_ip "$LAN_IP"; then
    error_exit "LAN IP 位址格式不正確！"
fi

read -p "請輸入要橋接的網路介面卡名稱（預設 ${DEFAULT_BRIDGE_IFACE}）: " BRIDGE_IFACE
BRIDGE_IFACE=${BRIDGE_IFACE:-$DEFAULT_BRIDGE_IFACE}

# ----- 檢查並建立 vmbr1 -----
if ! ip link show vmbr1 &>/dev/null; then
    echo "建立 vmbr1 橋接..."

    # 檢查橋接介面是否存在
    if ! ip link show "$BRIDGE_IFACE" &>/dev/null; then
        error_exit "橋接介面 $BRIDGE_IFACE 不存在！請確認介面名稱是否正確。"
    fi

    cat <<EOT >> /etc/network/interfaces.new # 暫存檔名，避免直接修改出錯
auto vmbr1
iface vmbr1 inet manual
    bridge-ports $BRIDGE_IFACE
    bridge-stp off
    bridge-fd 0
EOT

    # 備份原檔案並替換
    if [ -e /etc/network/interfaces ]; then
        mv /etc/network/interfaces /etc/network/interfaces.bak.$(date +%Y%m%d%H%M%S)
    fi
    mv /etc/network/interfaces.new /etc/network/interfaces

    # 使用 ifup/ifdown 啟動網橋，避免重啟整個 networking
    ifup vmbr1
    check_command_status "ifup vmbr1"
    echo "vmbr1 建立完成並橋接至 $BRIDGE_IFACE。"
else
    echo "vmbr1 已存在，跳過建立步驟。"
fi

# ----- 取得 OpenWRT 最新穩定版 -----
RELEASES_URL="https://downloads.openwrt.org/releases/"
STABLE_VERSION=$(curl -s "$RELEASES_URL" | grep -oP 'href="\K[0-9]+\.[0-9]+\.[0-9]+/"' | head -n 1 | tr -d '"/')

if [ -z "$STABLE_VERSION" ]; then
    error_exit "無法取得 OpenWRT 最新穩定版本號！請檢查網路連線或 OpenWRT 網站結構。"
fi

OPENWRT_IMG_URL="https://downloads.openwrt.org/releases/$STABLE_VERSION/targets/x86/64/openwrt-$STABLE_VERSION-x86-64-generic-ext4-combined-efi.img.gz"
OPENWRT_IMG_FILE="openwrt-$STABLE_VERSION-x86-64-generic-ext4-combined-efi.img"

echo "下載 OpenWRT $STABLE_VERSION EFI IMG..."
wget -q --show-progress "$OPENWRT_IMG_URL"
check_command_status "wget 下載 OpenWRT 映像檔"

echo "解壓縮 OpenWRT 映像檔..."
gunzip -f "openwrt-$STABLE_VERSION-x86-64-generic-ext4-combined-efi.img.gz"
check_command_status "gunzip 解壓縮映像檔"

# ----- 建立虛擬機 -----
echo "建立虛擬機..."
qm create "$VMID" --name "$VM_NAME" --onboot 1 --ostype l26 --machine q35 --bios ovmf --memory "$RAM_SIZE_MB" --cores "$CPU_COUNT" --cpu host --net0 virtio,bridge=vmbr0 --net1 virtio,bridge=vmbr1
check_command_status "qm create 建立虛擬機"

# ----- 匯入磁碟 -----
echo "匯入磁碟..."
qm importdisk "$VMID" "$OPENWRT_IMG_FILE" "$STORAGE_ID" --format raw
check_command_status "qm importdisk 匯入磁碟"
qm set "$VMID" --scsihw virtio-scsi-single --virtio0 "$STORAGE_ID:vm-$VMID-disk-0"
check_command_status "qm set --scsihw virtio-scsi-single --virtio0 設定磁碟"
echo "磁碟匯入完成。"

# ----- 啟動 VM -----
echo "啟動虛擬機..."
qm start "$VMID"
check_command_status "qm start 啟動虛擬機"
echo "虛擬機已啟動，VM ID: $VMID。"

# ----- 設定 OpenWRT 網路與安裝套件 (使用 qm terminal 並加入錯誤檢查) -----
echo "設定 OpenWRT 網路與安裝套件..."

# 定義要安裝的套件列表
packages="luci-i18n-base-zh-tw pciutils kmod-mt7921e mt7922bt-firmware kmod-mt7922-firmware wpa-supplicant hostapd"

# 使用 qm terminal 執行指令，並檢查錯誤
execute_remote_command() {
    local command="$1"
    local error_message="$2"
    local result remote_exit_code

    result=$(qm terminal "$VMID" --noecho --timeout 120 --command "$command ; echo \$?") 2>/dev/null # 忽略 qm terminal 的提示訊息，設定 timeout
    remote_exit_code=$(echo "$result" | tail -n 1) # 取得遠端指令的 exit code

    if ! [[ "$remote_exit_code" =~ ^[0-9]+$ ]]; then # 檢查 exit code 是否為數字
        error_exit "執行遠端指令時發生錯誤，無法取得 exit code：$error_message，完整輸出:\n$result"
    fi
    if [ "$remote_exit_code" -ne 0 ]; then
        error_exit "執行遠端指令失敗 (exit code: $remote_exit_code)：$error_message，完整輸出:\n$result"
    fi
}

# 設定 LAN IP
execute_remote_command "uci set network.lan.ipaddr='$LAN_IP' && uci commit network && /etc/init.d/network restart" "設定 OpenWRT LAN IP 位址失敗"

# 更新 opkg
execute_remote_command "opkg update" "更新 OpenWRT opkg 失敗"

# 迴圈安裝套件
for pkg in $packages; do
    execute_remote_command "opkg install $pkg" "安裝 OpenWRT 套件 $pkg 失敗"
done

echo "OpenWRT 基本設定與套件安裝完成。"

# ----- 清理安裝檔案 -----
echo "清理安裝檔案..."
rm -f "$OPENWRT_IMG_FILE" "$OPENWRT_IMG_FILE.gz"
check_command_status "rm 清理安裝檔案"
echo "清理完成。"


# ----- 輸出完成訊息 -----
echo "--------------------------------------------------"
echo "OpenWRT 虛擬機建立完成！"
echo "VM ID: $VMID"
echo "虛擬機名稱: $VM_NAME"
echo "LAN IP 位址: $LAN_IP"
echo "OpenWRT Web 介面: http://$LAN_IP"
echo "--------------------------------------------------"
echo "請手動設定 PCI passthrough，並將 m.2 Wi-Fi 卡直通給 VM ID $VMID，以啟用無線網路功能。"

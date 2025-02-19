#!/usr/bin/env bash
# https://openwrt.org/docs/guide-user/virtualization/qemu#openwrt_in_qemu_x86-64

# 取得 OpenWrt 的最新穩定版本
response=$(curl -s https://openwrt.org)
stableversion=$(echo "$response" | sed -n 's/.*Current stable release - OpenWrt \([0-9.]\+\).*/\1/p' | head -n 1)

# 下載 OpenWrt 映像的 URL
URL="https://downloads.openwrt.org/releases/$stableversion/targets/x86/64/openwrt-$stableversion-x86-64-generic-ext4-combined-efi.img.gz"

# 下載 OpenWrt 映像黨
wget -q --show-progress $URL

# 虛擬機配置
VMID=100
VMNAME="OpenWrt"
STORAGEID=$(cat /etc/pve/storage.cfg | grep "content images" -B 3 | awk 'NR==1{print $2}')
CORES=1
MEMORY=256
PCIID="0000:05:00.0"

# 解壓並調整磁碟映像大小
gunzip openwrt-*.img.gz
qemu-img resize -f raw openwrt-*.img 512M

# 安裝 parted
if ! command -v parted &> /dev/null
then
    echo "parted 未安装，正在安装..."
    apt install -y parted
else
    echo "parted 已安装"
fi

# 取得未使用磁碟裝置位置
loop_device=$(losetup -f)
# 掛載映像
losetup $loop_device openwrt-*.img
# 擴展第二磁區
parted -f -s "$loop_device" resizepart 2 100%
# 解除掛載磁碟
losetup -d $loop_device

# 創建虛擬機
qm create $VMID --name $VMNAME -ostype l26 --machine q35 --bios ovmf --scsihw virtio-scsi-single \
  --cores $CORES --cpu host --memory $MEMORY --net0 virtio,bridge=vmbr0 --net1 virtio,bridge=vmbr1 --onboot 1

# 將磁碟映像匯入 Proxmox 儲存空間
qm importdisk $VMID openwrt-*.img $STORAGEID
qm set $VMID --scsi0 $STORAGEID:vm-$VMID-disk-0
qm set $VMID --boot order=scsi0
qm set $VMID --hostpci0 $PCIID,pcie=1

# 啟動虛擬機
qm start $VMID

# 發送命令到虛擬機的函數
function send_line_to_vm() {
  for ((i = 0; i < ${#1}; i++)); do
    character=${1:i:1}
    case $character in
    " ") character="spc" ;;
    "-") character="minus" ;;
    "=") character="equal" ;;
    ",") character="comma" ;;
    ".") character="dot" ;;
    "/") character="slash" ;;
    "'") character="apostrophe" ;;
    ";") character="semicolon" ;;
    '\') character="backslash" ;;
    '`') character="grave_accent" ;;
    "[") character="bracket_left" ;;
    "]") character="bracket_right" ;;
    "_") character="shift-minus" ;;
    "+") character="shift-equal" ;;
    "?") character="shift-slash" ;;
    "<") character="shift-comma" ;;
    ">") character="shift-dot" ;;
    '"') character="shift-apostrophe" ;;
    ":") character="shift-semicolon" ;;
    "|") character="shift-backslash" ;;
    "~") character="shift-grave_accent" ;;
    "{") character="shift-bracket_left" ;;
    "}") character="shift-bracket_right" ;;
    "A") character="shift-a" ;;
    "B") character="shift-b" ;;
    "C") character="shift-c" ;;
    "D") character="shift-d" ;;
    "E") character="shift-e" ;;
    "F") character="shift-f" ;;
    "G") character="shift-g" ;;
    "H") character="shift-h" ;;
    "I") character="shift-i" ;;
    "J") character="shift-j" ;;
    "K") character="shift-k" ;;
    "L") character="shift-l" ;;
    "M") character="shift-m" ;;
    "N") character="shift-n" ;;
    "O") character="shift-o" ;;
    "P") character="shift-p" ;;
    "Q") character="shift-q" ;;
    "R") character="shift-r" ;;
    "S") character="shift-s" ;;
    "T") character="shift-t" ;;
    "U") character="shift-u" ;;
    "V") character="shift-v" ;;
    "W") character="shift-w" ;;
    "X") character="shift=x" ;;
    "Y") character="shift-y" ;;
    "Z") character="shift-z" ;;
    "!") character="shift-1" ;;
    "@") character="shift-2" ;;
    "#") character="shift-3" ;;
    '$') character="shift-4" ;;
    "%") character="shift-5" ;;
    "^") character="shift-6" ;;
    "&") character="shift-7" ;;
    "*") character="shift-8" ;;
    "(") character="shift-9" ;;
    ")") character="shift-0" ;;
    esac
    qm sendkey $VMID "$character"
  done
  qm sendkey $VMID ret
}

# 等待虛擬機開機完成
sleep 20

# 設置網絡配置
send_line_to_vm " "
send_line_to_vm "uci delete network.@device[0]"
send_line_to_vm "uci set network.wan=interface"
send_line_to_vm "uci set network.wan.device=eth0"
send_line_to_vm "uci set network.wan.proto=dhcp"
send_line_to_vm "uci delete network.lan"
send_line_to_vm "uci set network.lan=interface"
send_line_to_vm "uci set network.lan.device=eth1"
send_line_to_vm "uci set network.lan.proto=static"
send_line_to_vm "uci set network.lan.ipaddr='192.168.2.100'"
send_line_to_vm "uci set network.lan.netmask=255.255.255.0"
send_line_to_vm "uci set network.lan.gateway='192.168.2.1'"
send_line_to_vm "uci set network.lan.dns='8.8.8.8'"
send_line_to_vm "uci commit network"
send_line_to_vm "service network reload"

# 安裝所需的軟體包
send_line_to_vm "opkg update"
send_line_to_vm "opkg install luci-i18n-base-zh-tw"
send_line_to_vm "opkg install pciutils"
send_line_to_vm "opkg install kmod-mt7921e"
send_line_to_vm "opkg install mt7922bt-firmware"
send_line_to_vm "opkg install kmod-mt7922-firmware"
send_line_to_vm "opkg install wpad"
send_line_to_vm "opkg install qemu-ga"
send_line_to_vm "opkg install acpid"
send_line_to_vm "reboot"

# 清理下載的 OpenWrt 映像文件
rm -rf openwrt-*.img

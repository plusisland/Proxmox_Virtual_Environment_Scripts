#!/usr/bin/env bash
# https://openwrt.org/docs/guide-user/virtualization/qemu#openwrt_in_qemu_x86-64

# 取得 OpenWrt 的最新穩定版本
response=$(curl -s https://openwrt.org)
stableversion=$(echo "$response" | sed -n 's/.*Current stable release - OpenWrt \([0-9.]\+\).*/\1/p' | head -n 1)

# 下載 OpenWrt 映像的 URL
URL="https://downloads.openwrt.org/releases/$stableversion/targets/x86/64/openwrt-$stableversion-x86-64-generic-ext4-combined-efi.img.gz"

# 下載 OpenWrt 映像
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
sleep 20

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
    "X") character="shift-x" ;;
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


# 設置網絡配置
send_line_to_vm "uci delete network.@device[0]"
send_line_to_vm "uci set network.wan=interface"
send_line_to_vm "uci set network.wan.device=eth0"
send_line_to_vm "uci set network.wan.proto=dhcp"
send_line_to_vm "uci delete network.lan"
send_line_to_vm "uci set network.lan=interface"
send_line_to_vm "uci set network.lan.device=eth1"
send_line_to_vm "uci set network.lan.proto=static"
send_line_to_vm "uci set network.lan.ipaddr=192.168.2.1"
send_line_to_vm "uci set network.lan.netmask=255.255.255.0"
send_line_to_vm "uci commit"
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
send_line_to_vm "/etc/init.d/qemu-ga enable"
send_line_to_vm "reboot"

# 清理下載的 OpenWrt 映像文件
rm -rf openwrt-*.img.gz
==========================================================================
自訂shutdown命令
使用ssh登陸到Openwrt

# 生成一个shutdown文件
touch /sbin/shutdown
# 赋予执行权限
chmod +x /sbin/shutdown
# 写入内容
nano /sbin/shutdown
在文字中寫入以下內容

#!/bin/ash

# 默认使用关机命令
ACTION="poweroff"
# 默认倒数3s秒后执行命令
TIME="3s"

# 获取shutdown参数
# Qemu-GA 默认调用 -h -P +0的方式
while getopts "s:t:rkhncpP" OPT; do
    case $OPT in
        s|t)
        TIME="${OPTARG:-"now"}"
        ;;

        r)
        ACTION="reboot"
        ;;

        k)
        ACTION="warning"
        ;;

        h)
        ACTION="halt"
        ;;

        n)
        ACTION="poweroff"
        ;;

        c)
        echo "Cancel shutdown, but not support the Openwrt!" > /dev/kmsg
        ACTION="stop"
        ;;

        p|P)
        ACTION="poweroff"
        ;;

        \?)
        args=$@
        echo "Unrecognized arguments received: $args" > /dev/kmsg
        exit 1
        ;;
        esac
done

echo "Shutdown Script: Set ACTION to $ACTION" > /dev/kmsg
echo "Shutdown Script: Set TIME to $TIME" > /dev/kmsg

time=`echo $TIME | tr -cd "[0-9]"`

timeUnit=`echo $TIME | tr -cd "[A-Za-z]"`
if [ ! -n "$timeUnit"  ]; then
    timeUnit="s"
fi

if [ "$timeUnit" = "s" ]; then
    sleeptime=$time

elif [ "$timeUnit" = "m" ]; then
    sleeptime=$(($time*60));

elif [ "$timeUnit" = "h" ]; then
    sleeptime=$(($time*60*60));

elif [ "$timeUnit" = "d" ]; then
    sleeptime=$(($time*60*60*24));

elif [ "$timeUnit" = "y" ]; then
    sleeptime=$(($time*60*60*24*365));

else
    echo "Invalid arguments unit: $TIME" > /dev/kmsg
    exit 1
fi

echo "Shutdown Script: Waiting $TIME" > /dev/kmsg

while [ $sleeptime -gt 0 ];do
    if [ "$sleeptime" = "1" ]; then
        echo "Going Script!" > /dev/kmsg
    else
        echo "Please wait $(($sleeptime - 1))s" > /dev/kmsg
    fi
    sleep 1
    sleeptime=$(($sleeptime - 1))
done

if [ $# == 0 ]; then
    echo "Shutting down without any params" > /dev/kmsg
    /sbin/poweroff

elif [ "$ACTION" = "poweroff" ]; then
    /sbin/poweroff;

elif [ "$ACTION" = "reboot" ]; then
    /sbin/reboot

elif [ "$ACTION" = "warning" ]; then
    echo "关机警告" > /dev/kmsg
    /sbin/poweroff;

elif [ "$ACTION" = "halt" ]; then
    /sbin/halt
fi

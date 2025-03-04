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
# 擴展檔案系統
resize2fs ${loop_device}p2
# 解除掛載磁碟
losetup -d $loop_device

# 創建虛擬機
qm create $VM_ID \
  --name $VM_NAME \
  -ostype l26 \
  --machine q35 \
  --bios ovmf \
  --scsihw virtio-scsi-single \
  --cores $CORES \
  --cpu host \
  --memory $MEMORY \
  --net0 virtio,bridge=vmbr0 \
  --net1 virtio,bridge=vmbr1 \
  --onboot 1

# 將磁碟映像匯入 Proxmox 儲存空間
qm importdisk $VM_ID openwrt-*.img $STORAGE_ID
qm set $VM_ID \
  --scsi0 $STORAGE_ID:vm-$VM_ID-disk-0 \
  --boot order=scsi0 \
  --hostpci0 $PCI_ID,pcie=1 \
  --usb0 host=$USB_ID
  
# 清理下載的 OpenWrt 映像文件
rm -rf openwrt-*.img

# 啟動虛擬機
qm start $VM_ID

# https://gitlab.com/qemu-project/qemu/-/blob/master/pc-bios/keymaps/en-us
# 這個函數會根據QEMU的鍵盤編碼將文字轉換為sendkey命令
qm_sendline() {
    local text="$1"     # 要轉換的文字
	echo -e "發送命令:$text"
    # 創建一個鍵位對應表，去掉了小寫字母和數字
    declare -A key_map=(
        ['A']='shift-a'
        ['B']='shift-b'
        ['C']='shift-c'
        ['D']='shift-d'
        ['E']='shift-e'
        ['F']='shift-f'
        ['G']='shift-g'
        ['H']='shift-h'
        ['I']='shift-i'
        ['J']='shift-j'
        ['K']='shift-k'
        ['L']='shift-l'
        ['M']='shift-m'
        ['N']='shift-n'
        ['O']='shift-o'
        ['P']='shift-p'
        ['Q']='shift-q'
        ['R']='shift-r'
        ['S']='shift-s'
        ['T']='shift-t'
        ['U']='shift-u'
        ['V']='shift-v'
        ['W']='shift-w'
        ['X']='shift-x'
        ['Y']='shift-y'
        ['Z']='shift-z'
        [' ']='spc'
        ['`']='grave_accent'
        ['~']='shift-grave_accent'
        ['!']='shift-1'
        ['@']='shift-2'
        ['#']='shift-3'
        ['$']='shift-4'
        ['%']='shift-5'
        ['^']='shift-6'
        ['&']='shift-7'
        ['*']='shift-8'
        ['(']='shift-9'
        [')']='shift-0'
        ['-']='minus'
        ['_']='shift-minus'
        ['=']='equal'
        ['+']='shift-equal'
        ['[']='bracket_left'
        ['{']='shift-bracket_left'
        [']']='bracket_right'
        ['}']='shift-bracket_right'
        ['\']='backslash'
        ['|']='shift-backslash'
        [';']='semicolon'
        [':']='shift-semicolon'
        ["'"]='apostrophe'
        ['"']='shift-apostrophe'
        [',']='comma'
        ['<']='shift-comma'
        ['.']='dot'
        ['>']='shift-dot'
        ["/"]='slash'
        ['?']='shift-slash'
    )

    # 遍歷輸入文字，並發送對應的sendkey命令
    for (( i=0; i<${#text}; i++ )); do
        char=${text:$i:1}
        if [[ -v key_map[$char] ]]; then
            key=${key_map[$char]}
            qm sendkey $VM_ID $key
        else
            qm sendkey $VM_ID $char
        fi
    done
    qm sendkey $VM_ID ret
}

# 輸出`需要補\`
# 輸出\需要補成\\
# 輸出"需要補成\"
#send_keys 100 "Aa \`~!@#$%^&*()-_=+[{]}\\|;:'\",<.>/?"

# 等待虛擬機開機完成
echo "等待虛擬機開機完成"
sleep 20
# 輸入 enter 進入命令列
qm_sendline ""
qm_sendline "uci delete network.@device[0]"
# Configure network
qm_sendline "uci set network.wan=interface"
qm_sendline "uci set network.wan.device=eth0"
qm_sendline "uci set network.wan.proto=dhcp"
qm_sendline "uci set network.lan=interface"
qm_sendline "uci set network.lan.device=br-lan"
qm_sendline "uci set network.lan.proto=static"
qm_sendline "uci set network.lan.ipaddr=$LAN_IP"
qm_sendline "uci set network.lan.netmask=$NET_MASK"
qm_sendline "uci set network.lan.type=bridge"
qm_sendline "uci set network.lan.ifname=eth1"
qm_sendline "uci delete network.wan6"
qm_sendline "uci commit network"
qm_sendline "service network restart"
# Configure DHCP
qm_sendline "uci set dhcp.lan.interface=lan"
qm_sendline "uci set dhcp.lan=dhcp"
qm_sendline "uci set dhcp.lan.start=100"
qm_sendline "uci set dhcp.lan.limit=100"
qm_sendline "uci set dhcp.lan.leasetime=12h"
qm_sendline "uci commit dhcp"
qm_sendline "service dnsmasq restart"
echo "等待網路重啟"
sleep 3
qm_sendline "opkg update"
echo "等待套件清單更新"
sleep 5
qm_sendline "opkg install luci-i18n-base-zh-tw"
ipk_url=$(curl -s https://api.github.com/repos/jerrykuku/luci-theme-argon/releases | grep '"browser_download_url":' | grep 'luci-theme-argon.*_all\.ipk' | head -n 1 | sed -n 's/.*"browser_download_url": "\([^"]*\)".*/\1/p')
qm_sendline "wget -O luci-theme-argon.ipk $ipk_url"
qm_sendline "opkg install luci-theme-argon.ipk"
qm_sendline "rm -rf luci-theme-argon.ipk"
qm_sendline "opkg install pciutils wpad-openssl usbutils kmod-usb2-pci bluez-daemon acpid qemu-ga luci-compat luci-lib-ipkg"
sleep 30

# 判斷網卡類型並安裝對應驅動
if lspci | grep -q "AX210"; then
    echo "偵測到 Intel AX210 網卡，安裝 iwlwifi 驅動..."
    qm_sendline "opkg install kmod-iwlwifi iwlwifi-firmware-ax210"
	sleep 10
	# Configure wireless
    qm_sendline "uci set wireless.radio0.disabled=0"
	qm_sendline "uci set wireless.radio0.htmode=HE40"
    qm_sendline "uci set wireless.radio0.channel=6"
    qm_sendline "uci set wireless.radio0.band='2g'"
    qm_sendline "uci set wireless.radio0.country=TW"
    qm_sendline "uci set wireless.default_radio0.network=lan"
    qm_sendline "uci set wireless.default_radio0.mode=ap"
    qm_sendline "uci set wireless.default_radio0.ssid=OpenWrt"
    qm_sendline "uci set wireless.default_radio0.encryption=none"
    qm_sendline "sed -i '/exit 0/i\\sleep 10 && wifi && service bluetoothd restart' /etc/rc.local"
    qm_sendline "uci commit wireless"
    qm_sendline "service wireless reload"
elif lspci | grep -q "MT7922"; then
    echo "偵測到 MediaTek MT7922 網卡，安裝 mt7921e 驅動..."
    qm_sendline "opkg install kmod-mt7921e kmod-mt7922-firmware mt7922bt-firmware"
	sleep 10
	# Configure wireless
    qm_sendline "uci set wireless.radio0.disabled=0"
    qm_sendline "uci set wireless.radio0.hwmode=11ax"
    qm_sendline "uci set wireless.radio0.htmode=HE80"
    qm_sendline "uci set wireless.radio0.channel=auto"
    qm_sendline "uci set wireless.radio0.band='auto'"
    qm_sendline "uci set wireless.radio0.country=TW"
    qm_sendline "uci set wireless.default_radio0.network=lan"
    qm_sendline "uci set wireless.default_radio0.mode=ap"
    qm_sendline "uci set wireless.default_radio0.ssid=OpenWrt"
    qm_sendline "uci set wireless.default_radio0.encryption=none"
    qm_sendline "sed -i '/exit 0/i\\sleep 10 && wifi && service bluetoothd restart' /etc/rc.local"
    qm_sendline "uci commit wireless"
    qm_sendline "service wireless reload"
else
    echo "未偵測到 Intel AX210 或 MediaTek MT7922 網卡，跳過驅動安裝。"
fi

echo "重啟虛擬機。"
qm_sendline "reboot"
# https://www.yumao.name/read/openwrt-share-network-via-bluetooth 藍芽使用 NAP 共享網路請參考 https://elinux.org/images/1/15/ELC_NA_2019_PPT_CreatingBT_PAN_RNDIS_router_using_OpenWrt_20190814r1.pdf

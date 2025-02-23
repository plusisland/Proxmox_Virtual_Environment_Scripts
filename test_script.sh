#!/usr/bin/env bash
# https://openwrt.org/docs/guide-user/virtualization/qemu#openwrt_in_qemu_x86-64
# https://github.com/kjames2001/OpenWRT-PVE-AP-MT7922
# 為了網卡直通必須選用 q35 , VMOF 且包含 EFI 的映象檔，內建 EFI 磁碟區可建立可不建。建了只是為了避免沒 EFI 磁碟區警告，這邊選擇不建立。
# 選i440fx , SeaBIOS 就不需要 EFI 版本，但是直通網路速度較差。

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
STORAGEID=$(grep "content images" -B 3 /etc/pve/storage.cfg | awk 'NR==1{print $2}')
CORES=1
MEMORY=256
# 藍芽走USB
#USBID=$(lsusb | grep Wireless | awk '{print $6}')
# WIFI走PCI
PCIID=$(lspci | grep Network | awk '{print $1}')

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
qm create $VMID \
  --name $VMNAME \
  -ostype l26 \
  --machine q35 \
  --bios ovmf \
  --scsihw virtio-scsi-single \
  --cores $CORES \
  --cpu host \
  --memory $MEMORY \
  --net0 virtio,bridge=vmbr0 \
  --net1 virtio,bridge=vmbr1 \
  --net2 virtio,bridge=vmbr2 \
  --net3 virtio,bridge=vmbr3 \
  --onboot 1

# 將磁碟映像匯入 Proxmox 儲存空間
qm importdisk $VMID openwrt-*.img $STORAGEID
qm set $VMID \
  --scsi0 $STORAGEID:vm-$VMID-disk-0 \
  --boot order=scsi0 \
#  --usb0 host=$USBID \
  --hostpci0 $PCIID,pcie=1

# 清理下載的 OpenWrt 映像文件
rm -rf openwrt-*.img

# 啟動虛擬機
qm start $VMID

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
            qm sendkey $VMID $key
        else
            qm sendkey $VMID $char
        fi
    done
    qm sendkey $VMID ret
}

# 用法示例
#send_keys 100 "Aa \`~!@#$%^&*()-_=+[{]}\\|;:'\",<.>/?"

# 等待虛擬機開機完成
echo "等待虛擬機開機完成"
sleep 20
# 輸入 enter 進入命令列
qm_sendline ""
qm_sendline "uci delete network.@device[0]"
qm_sendline "uci set network.wan=interface"
qm_sendline "uci set network.wan.device=eth0"
qm_sendline "uci set network.wan.proto=dhcp"
qm_sendline "uci set network.lan=interface"
qm_sendline "uci set network.lan.device=br-lan"
qm_sendline "uci set network.lan.proto=static"
qm_sendline "uci set network.lan.ipaddr=192.168.2.1"
qm_sendline "uci set network.lan.netmask=255.255.255.0"
qm_sendline "uci set network.lan.type=bridge"
qm_sendline "uci set network.lan.ifname='eth1 eth2 eth3'"
qm_sendline "uci set dhcp.lan.interface=lan"
qm_sendline "uci set dhcp.lan=dhcp"
qm_sendline "uci set dhcp.lan.start=100"
qm_sendline "uci set dhcp.lan.limit=100"
qm_sendline "uci set dhcp.lan.leasetime=12h"
qm_sendline "uci delete network.wan6"
qm_sendline "uci commit network"
qm_sendline "uci commit dhcp"
qm_sendline "service network reload"
echo "等待網路重啟"
sleep 3
qm_sendline "opkg update"
echo "等待套件清單更新"
sleep 5
# 安裝 wpad-openssl 就會自動安裝所有網路相依套件
# 安裝 acpid 是為了讓 openwrt 支援接收虛擬發的關機指令
# qemu-ga 不用裝，裝了只能從虛擬機控制面板看 IP，一樣不支援主控台複製貼上指令。且還會造成關機指令無效。
qm_sendline "opkg install luci-i18n-base-zh-tw pciutils kmod-mt7921e kmod-mt7922-firmware wpad-openssl acpid"
# https://www.yumao.name/read/openwrt-share-network-via-bluetooth 藍芽使用 NAP 共享網路
# 根據此篇方法查詢
# https://sibsaidinblog-tw.blogspot.com/2016/09/bluetooth-obex.html 
# UUID: Generic Attribute Profile (00001801-0000-1000-8000-00805f9b34fb)
# UUID: Generic Access Profile    (00001800-0000-1000-8000-00805f9b34fb)
# UUID: PnP Information           (00001200-0000-1000-8000-00805f9b34fb)
# UUID: A/V Remote Control Target (0000110c-0000-1000-8000-00805f9b34fb)
# UUID: A/V Remote Control        (0000110e-0000-1000-8000-00805f9b34fb)
# UUID: Device Information        (0000180a-0000-1000-8000-00805f9b34fb)
# 看來不支援 NAP
#qm_sendline "opkg install kmod-usb2-pci bluez-daemon mt7922bt-firmware"
# https://openwrt.org/docs/guide-user/hardware/bluetooth/usb.bluetooth
# 安裝 kmod-usb2-pci bluez-daemon mt7922bt-firmware 只能做一般配對
# 配對方法 bluetoothctl -----> scan on -----> trust -----> pair -----> connect
echo "等待套件下載"
sleep 30
qm_sendline "uci set wireless.radio0.disabled=0"
qm_sendline "uci set wireless.radio0.channel=auto"
qm_sendline "uci set wireless.radio0.htmode=HE80"
qm_sendline "uci set wireless.radio0.country=TW"
qm_sendline "uci set wireless.radio0.hwmode=11ax"
qm_sendline "uci set wireless.radio0.band='auto'"
qm_sendline "uci set wireless.default_radio0.network=lan"
qm_sendline "uci set wireless.default_radio0.mode=ap"
qm_sendline "uci set wireless.default_radio0.ssid=OpenWrt"
qm_sendline "uci set wireless.default_radio0.encryption=none"
qm_sendline "sed -i '/exit 0/i\\sleep 10 && wifi' /etc/rc.local"
qm_sendline "uci commit wireless"
qm_sendline "service wireless reload"
qm_sendline "opkg install luci-compat"
qm_sendline "opkg install luci-lib-ipkg"
ipk_url=$(curl -s https://api.github.com/repos/jerrykuku/luci-theme-argon/releases | grep '"browser_download_url":' | grep 'luci-theme-argon.*_all\.ipk' | head -n 1 | sed -n 's/.*"browser_download_url": "\([^"]*\)".*/\1/p')
qm_sendline "wget -O luci-theme-argon.ipk $ipk_url"
qm_sendline "opkg install luci-theme-argon.ipk"
qm_sendline "rm -rf luci-theme-argon.ipk"
echo "重啟虛擬機。"
qm_sendline "reboot"

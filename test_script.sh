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

# 安裝 parted 和 expect
if ! command -v parted &> /dev/null
then
    echo "parted 未安装，正在安装..."
    apt install -y parted
else
    echo "parted 已安装"
fi

# 获取未使用的循环设备
loop_device=$(losetup -f)
# 将映像文件挂载到循环设备
losetup $loop_device openwrt-*.img
# 扩展第二个分区到剩余空间
parted -f -s "$loop_device" resizepart 2 100%
# 解除挂载循环设备
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
  declare -A char_map=([" "] = "spc" ["-"] = "minus" ["="] = "equal" [","] = "comma" ["."] = "dot" ["/"] = "slash" ["'"] = "apostrophe" [";"] = "semicolon" ["\\"] = "backslash" ["\`"] = "grave_accent" ["["] = "bracket_left" ["]"] = "bracket_right" ["_"] = "shift-minus" ["+"] = "shift-equal" ["?"] = "shift-slash" ["<"] = "shift-comma" [">"] = "shift-dot" ['"'] = "shift-apostrophe" [":"] = "shift-semicolon" ["|"] = "shift-backslash" ["~"] = "shift-grave_accent" ["{"] = "shift-bracket_left" ["}"] = "shift-bracket_right" ["!"] = "shift-1" ["@"] = "shift-2" ["#"] = "shift-3" ["$"] = "shift-4" ["%"] = "shift-5" ["^"] = "shift-6" ["&"] = "shift-7" ["*"] = "shift-8" ["("] = "shift-9" [")"] = "shift-0"
  )

  for ((i = 0; i < ${#1}; i++)); do
    character=${1:i:1}

    if [[ "$character" =~ [a-z] ]]; then  # 判斷是否為小寫字母
      key_name="$character"
    elif [[ "$character" =~ [A-Z] ]]; then  # 判斷是否為大寫字母
      key_name="shift-${character,,}"  # 轉換為小寫並加上 shift- 前綴
    elif [[ -v char_map["$character"] ]]; then # 檢查是否在關聯陣列中
      key_name="${char_map["$character"]}"
    else
      key_name="$character" # 預設情況，直接使用字元本身 (例如數字)
      # key_name="" # 或者，如果遇到未定義字元，可以設定為空字串或跳過
      # continue # 或者，跳過未定義字元
    fi

    if [[ -n "$key_name" ]]; then # 確保 key_name 不是空字串才發送
      qm sendkey $VMID "$key_name"
    fi
  done
  qm sendkey $VMID ret
}

# 等待虛擬機開機完成
sleep 20

# 設置網絡配置
send_line_to_vm ""
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

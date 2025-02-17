#!/usr/bin/env bash
https://openwrt.org/docs/guide-user/virtualization/qemu#openwrt_in_qemu_x86-64

# 假設您已經下載了OpenWRT EFI圖像至Proxmox主機的當前目錄
OPENWRT_IMG="openwrt-23.05.3-x86-64-generic-ext4-combined-efi.img.gz"
VMID=100  # 請根據您的需要更改VM ID
STORAGEID="local-lvm"  # 更改為您的儲存ID
VMNAME="OpenWrt"
MEMORY=256  # MB
CORES=1
PCI_ADDR="0000:01:00.0"  # 請根據您的PCIe網卡的地址調整
echo $PCI_ADDR > /sys/bus/pci/drivers/vfio-pci/new_id

# 解壓縮圖像
gzip -d $OPENWRT_IMG

# 調整圖像大小（這裡我們設為2GB，但您可以根據需要調整）
qemu-img resize -f raw ${OPENWRT_IMG%.gz} 512MB

# 創建VM，但不啟動它
qm create $VMID --name $VMNAME --machine q35 --bios ovmf --memory $MEMORY --cores $CORES --net0 virtio,bridge=vmbr0

# 導入OpenWRT圖像作為VM的磁碟
qm importdisk $VMID ${OPENWRT_IMG%.gz} $STORAGEID

# 編輯硬體配置，將導入的磁碟附加為主要啟動裝置
qm set $VMID --scsihw virtio-scsi-pci
qm set $VMID --scsi0 $STORAGEID:vm-$VMID-disk-0

# 設置啟動順序
qm set $VMID --boot order=scsi0
qm set $VMID --hostpci0 $PCI_ADDR,pcie=1,x-vga=1

# 清理臨時文件（可選）
rm ${OPENWRT_IMG%.gz}

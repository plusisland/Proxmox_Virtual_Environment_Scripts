#!/usr/bin/env bash

# https://hackmd.io/@davidho9713/pve_pci_passthrough
# https://pve.proxmox.com/wiki/PCI(e)_Passthrough
# https://pve.proxmox.com/wiki/PCI_Passthrough

# 獲取 CPU 型號
cpu_vendor=$(lscpu | grep "Vendor ID" | awk '{print $3}')

# 判斷 CPU 型號並設置相應的參數
cpu_platform="$(lscpu | grep 'Model name' | grep -E 'Intel|AMD')"
case $cpu_platform in
    *Intel*)
    # 如果是 Intel CPU
          CPU="Intel"
          echo "偵測到本平台為 Intel 平台,正在修改IOMMU參數..."
          sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="quiet"/GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt"/' /etc/default/grub
          sed -i 's/root=ZFS=rpool\/ROOT\/pve-1 boot=zfs/root=ZFS=rpool\/ROOT\/pve-1 boot=zfs intel_iommu=on iommu=pt/' /etc/kernel/cmdline
          ;;
    *AMD*)
     # 如果是 AMD CPU
          CPU="AMD"
          echo "偵測到本平台為 AMD 平台,正在修改IOMMU參數..."   
          sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="quiet"/GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on iommu=pt"/' /etc/default/grub
          sed -i 's/root=ZFS=rpool\/ROOT\/pve-1 boot=zfs/root=ZFS=rpool\/ROOT\/pve-1 boot=zfs amd_iommu=on iommu=pt/' /etc/kernel/cmdline
          ;;
    *)
          echo -e "抱歉,暫不支持當前CPU平台!"
          ;;
esac

# 更新 grub
echo "正在更新 GRUB 核心參數..."
proxmox-boot-tool refresh

# 加載核心模塊
echo "正在加載核心模塊..."
echo "vfio" >> /etc/modules
echo "vfio_iommu_type1" >> /etc/modules
echo "vfio_pci" >> /etc/modules

echo "blacklist amdgpu" >> /etc/modprobe.d/blacklist.conf
echo "blacklist radeon" >> /etc/modprobe.d/blacklist.conf

echo "blacklist nouveau" >> /etc/modprobe.d/blacklist.conf 
echo "blacklist nvidia*" >> /etc/modprobe.d/blacklist.conf 

echo "blacklist i915" >> /etc/modprobe.d/blacklist.conf

echo "blacklist mt7921e" >> /etc/modprobe.d/blacklist.conf

# 更新核心參數
echo "正在更新核心參數..."
update-initramfs -u -k all

echo "腳本運行完成，已成功開啟硬件直通功能."

echo "正在執行重啟...請等待1-3分鐘..."
reboot

#!/usr/bin/env bash
# https://pve.proxmox.com/pve-docs/chapter-qm.html#_general_requirements

# 預設 IOMMU 參數
IOMMU_PARAMS="iommu=pt"

# 檢查 CPU 廠商並設定 Intel IOMMU 參數
[[ $(lscpu | grep "Vendor ID:") =~ "GenuineIntel" ]] && IOMMU_PARAMS="$IOMMU_PARAMS intel_iommu=on"

# 更新 GRUB 設定
if [ -f /etc/default/grub ] && ! grep -q "$IOMMU_PARAMS" /etc/default/grub; then
  sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 '"$IOMMU_PARAMS"'"/' /etc/default/grub
  update-grub
fi

# 更新 Kernel Cmdline 設定 (systemd-boot)
if [ -f /etc/kernel/cmdline ] && ! grep -q "$IOMMU_PARAMS" /etc/kernel/cmdline; then
  sed -i '$ s/$/ '"$IOMMU_PARAMS"'/g' /etc/kernel/cmdline
  proxmox-boot-tool refresh
fi

# 載入核心模組
for MODULE in vfio vfio_iommu_type1 vfio_pci; do
  grep -q "$MODULE" /etc/modules || echo "$MODULE" >> /etc/modules
done

# 更新核心參數
update-initramfs -u -k all
reboot

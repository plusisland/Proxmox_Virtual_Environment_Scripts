#!/usr/bin/env bash
# https://pve.proxmox.com/pve-docs/chapter-qm.html#_general_requirements

# 預設 IOMMU 參數 | Default IOMMU parameters
IOMMU_PARAMS="iommu=pt"

# 檢查 CPU 廠商並設定 Intel IOMMU 參數 | Check CPU vendor and set Intel IOMMU parameters
[[ $(lscpu | grep "Vendor ID:") =~ "GenuineIntel" ]] && IOMMU_PARAMS="$IOMMU_PARAMS intel_iommu=on"

# 更新 GRUB 設定 | Update GRUB configuration
if [ -f /etc/default/grub ] && ! grep -q "$IOMMU_PARAMS" /etc/default/grub; then
  sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 '"$IOMMU_PARAMS"'"/' /etc/default/grub
  update-grub
fi

# 更新 Kernel Cmdline 設定 (systemd-boot) | Update Kernel Cmdline configuration (systemd-boot)
if [ -f /etc/kernel/cmdline ] && ! grep -q "$IOMMU_PARAMS" /etc/kernel/cmdline; then
  sed -i '$ s/$/ '"$IOMMU_PARAMS"'/g' /etc/kernel/cmdline
  proxmox-boot-tool refresh
fi

# 載入核心模組 | Load kernel modules
for MODULE in vfio vfio_iommu_type1 vfio_pci; do
  grep -q "$MODULE" /etc/modules || echo "$MODULE" >> /etc/modules
done

# 更新核心參數 | Update kernel parameters
update-initramfs -u -k all

# 重新開機 | Reboot
echo "重新開機，請等待幾秒鐘後手動重新整理您的網頁(畫面顯示時間取決於您的硬體開機速度) | Rebooting, please wait a few seconds before manually refreshing your webpage (the time displayed depends on your hardware boot speed)."
reboot

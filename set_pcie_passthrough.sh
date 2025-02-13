#!/usr/bin/env bash

IOMMU_PARAMS="iommu=pt"

# 更新 GRUB 設定
if [ -f /etc/default/grub ]; then
  if ! grep -q "$IOMMU_PARAMS" /etc/default/grub; then
    sed -i "s/^GRUB_CMDLINE_LINUX_DEFAULT=\"quiet\"/GRUB_CMDLINE_LINUX_DEFAULT=\"quiet $IOMMU_PARAMS\"/" /etc/default/grub
    update-grub
  fi
fi

# 更新 systemd-boot 設定
if [ -f /etc/kernel/cmdline ]; then
  if ! grep -q "$IOMMU_PARAMS" /etc/kernel/cmdline; then
    sed -i "s|^root=ZFS=rpool/ROOT/pve-1 boot=zfs|root=ZFS=rpool/ROOT/pve-1 boot=zfs $IOMMU_PARAMS|" /etc/kernel/cmdline
    proxmox-boot-tool refresh
  fi
fi

# 加載核心模組
MODULES="vfio vfio_iommu_type1 vfio_pci"
for MODULE in $MODULES; do
  grep -q "$MODULE" /etc/modules || echo "$MODULE" >> /etc/modules
done

# 更新核心參數
update-initramfs -k all -u
reboot

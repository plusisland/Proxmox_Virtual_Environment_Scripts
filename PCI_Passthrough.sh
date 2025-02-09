#!/usr/bin/env bash
# https://pve.proxmox.com/wiki/PCI(e)_Passthrough
# https://pve.proxmox.com/wiki/PCI_Passthrough
# https://hackmd.io/@davidho9713/pve_pci_passthrough

# 設定直通模式
if ! dmesg | grep -q "DMAR: IOMMU enabled"; then
  if grep -q "iommu=pt" /etc/kernel/cmdline; then
    echo "檔案 /etc/kernel/cmdline 已經包含 iommu=pt，無需修改。"
  else
    echo "新 CPU 都已預設啟用 IOMMU，只設定增進效能..."
    search="root=ZFS=rpool\/ROOT\/pve-1 boot=zfs"
    replace="root=ZFS=rpool\/ROOT\/pve-1 boot=zfs iommu=pt"
    if ! sed -i "s/$search/$replace/g" /etc/kernel/cmdline; then
      echo "修改 /etc/kernel/cmdline 失敗！"
      exit 1
    fi
    echo "檔案 /etc/kernel/cmdline 已成功修改。"
    echo "正在更新開機核心參數..."
    proxmox-boot-tool refresh
  fi
else
  echo "IOMMU 已啟用，無需修改 /etc/kernel/cmdline。"
fi

# 修改核心模組
modules=("vfio" "vfio_iommu_type1" "vfio_pci")
for module in "${modules[@]}"; do
  if ! grep -q "$module" /etc/modules; then
    echo "$module" >> /etc/modules
    echo "模組 $module 已新增到 /etc/modules。"
  else
    echo "模組 $module 已存在於 /etc/modules 中，無需重複添加。"
  fi
done

# 主機阻斷硬體
modules=("amdgpu" "radeon" "nouveau" "nvidia*" "i915" "mt7921e")

# 檢查檔案是否存在，不存在則建立
if [ ! -f /etc/modprobe.d/blacklist.conf ]; then
  touch /etc/modprobe.d/blacklist.conf
fi

# 逐個檢查是否已在黑名單中
for module in "${modules[@]}"; do
  if ! grep -q "blacklist $module" /etc/modprobe.d/blacklist.conf; then
    echo "blacklist $module" >> /etc/modprobe.d/blacklist.conf
    echo "硬體 $module 已加入黑名單。"
  else
    echo "硬體 $module 已在黑名單中，無需重複添加。"
  fi
done

# 更新核心參數
echo "正在更新核心參數..."
update-initramfs -u -k all

echo "命令執行完成，已成功開啟硬體直通功能。系統將在 3 秒後重新啟動..."
sleep 3
reboot

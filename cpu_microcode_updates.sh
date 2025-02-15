#!/usr/bin/env bash
# https://pve.proxmox.com/pve-docs/chapter-sysadmin.html#sysadmin_firmware_cpu

# 啟用 Debian non-free-firmware 套件庫 | Enabling Debian non-free-firmware repository
echo "檢查並啟用 Debian non-free-firmware 套件庫... | Checking and enabling Debian non-free-firmware repository..."
sed -i '/\.debian.org\/debian bookworm main contrib/s/$/ non-free-firmware/' /etc/apt/sources.list

# 更新套件清單 | Update the package lists
echo "更新套件清單中... | Updating package lists..."
apt update

# 安裝對應的微碼套件 | Install the appropriate microcode package
echo "檢查 CPU 型號並安裝對應的微碼套件... | Checking CPU vendor and installing the corresponding microcode package..."
if lscpu | grep -q "GenuineIntel"; then
  echo "偵測到 Intel CPU，安裝 intel-microcode... | Intel CPU detected, installing intel-microcode..."
  apt install -y intel-microcode
elif lscpu | grep -q "AuthenticAMD"; then
  echo "偵測到 AMD CPU，安裝 amd64-microcode... | AMD CPU detected, installing amd64-microcode..."
  apt install -y amd64-microcode
else
  echo "無法偵測到有效的 CPU 型號，請檢查系統。| Unable to detect a valid CPU model, please check the system."
  exit 1
fi

# 重新啟動 Proxmox VE 主機 | Reboot the Proxmox VE host
echo "微碼安裝完成，系統將重新啟動。 | Microcode installation completed, rebooting the system."
reboot

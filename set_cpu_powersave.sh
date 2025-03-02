#!/bin/bash
# https://forum.proxmox.com/threads/fix-always-high-cpu-frequency-in-proxmox-host.84270/page-3

# 檢查是否已安裝 cpufrequtils 並處理移除選項
if dpkg -s cpufrequtils > /dev/null 2>&1; then
  echo "已安裝 cpufrequtils。| cpufrequtils is already installed."
  read -p "是否移除？ (y/n): | Remove installed cpufrequtils? (y/n): " remove_choice
  if [[ "$remove_choice" == "y" || "$remove_choice" == "Y" ]]; then
    echo "正在移除... | Removing..."
    apt-get remove -y cpufrequtils && echo "已移除。| Removed." || { echo "移除失敗。| Removal failed." ; exit 1; }
  else
    echo "保留已安裝版本。| Keeping installed version."
  fi
else
  echo "未安裝 cpufrequtils。| cpufrequtils is not installed."
  echo "正在安裝... | Installing..."
  apt-get update && apt-get install -y cpufrequtils && echo "已安裝。| Installed." || { echo "安裝失敗。| Installation failed." ; exit 1; }
fi

# 檢查 /etc/default/cpufrequtils 是否存在，不存在則建立並設定 powersave，存在則直接設定
if [ ! -f /etc/default/cpufrequtils ]; then
  echo "/etc/default/cpufrequtils 不存在，建立並設定 powersave... | /etc/default/cpufrequtils does not exist, creating and setting powersave..."
  echo 'GOVERNOR="powersave"' > /etc/default/cpufrequtils && echo "已建立並設定。| Created and set." || { echo "建立失敗。| Creation failed." ; exit 1; }
else
  echo "/etc/default/cpufrequtils 已存在，設定 powersave... | /etc/default/cpufrequtils already exists, setting powersave..."
  sed -i 's/^GOVERNOR="\(.*\)".*/GOVERNOR="powersave"/' /etc/default/cpufrequtils && echo "已設定。| Set." || { echo "設定失敗。| Setting failed." ; exit 1; }
fi

# 重啟 cpufrequtils 服務
echo "重新啟動 cpufrequtils 服務... | Restarting cpufrequtils service..."
systemctl restart cpufrequtils && echo "服務已重啟。| Service restarted." || echo "服務重啟失敗，請手動重啟。| Service restart failed, please restart manually."

echo "腳本執行完成。| Script execution completed."

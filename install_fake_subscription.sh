#!/usr/bin/env bash
# https://github.com/Jamesits/pve-fake-subscription/tree/master

package_name="pve-fake-subscription"
deb_url=$(curl -s https://api.github.com/repos/Jamesits/pve-fake-subscription/releases/latest | grep -oP '(?<="browser_download_url": ")[^"]+.deb')
tmp_deb_path="/tmp/$package_name.deb"

echo "PVE Fake Subscription 安裝/移除工具"
if dpkg-query -W -f='${Status}' "$package_name" 2>/dev/null | grep -q "installed"; then
    read -p "$package_name 已安裝，是否移除？ (y/n): " remove_choice
    [[ "$remove_choice" == "y" ]] && apt-get purge -y "$package_name" && echo "$package_name 已移除。" || echo "操作已取消。"
else
    read -p "$package_name 未安裝，是否安裝？ (y/n): " install_choice
    if [[ "$install_choice" == "y" ]]; then
        if [[ -z "$deb_url" ]]; then
            echo "錯誤：無法取得下載鏈結，請檢查網路。"
            exit 1
        fi
        echo "正在下載及安裝 $package_name ..."
        if wget --show-progress -O "$tmp_deb_path" "$deb_url" && dpkg -i "$tmp_deb_path"; then
            rm "$tmp_deb_path"
            echo "$package_name 安裝完成！"
            echo "⚠️ 注意：安裝後請勿點擊「技術授權合約」頁面中的「檢查」按鈕，以避免恢復未授權狀態。"
            echo "🔹 虛假訂閱不提供企業存儲庫訪問權限。"
        else
            echo "❌ 錯誤：安裝失敗，請檢查網路或日誌。"
            rm -f "$tmp_deb_path"
            exit 1
        fi
    else
        echo "操作已取消。"
    fi
fi

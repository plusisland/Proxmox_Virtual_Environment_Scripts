#!/usr/bin/env bash
# https://forum.snkms.com/post-599

file="/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js"

read -p "要隱藏無訂閱訊息視窗嗎？(y/n/r): " choice

case "$choice" in
  y)
    sed -i 's/Ext.Msg.show({\n\s*title: gettext(\'No valid subscription\'/Ext.Msg.noshow({\n\s*title: gettext(\'No valid subscription\'/g' "$FILE"
    echo "檔案 $file 已修改，重新啟動 pveproxy。"
    systemctl restart pveproxy
    ;;
  n)
    echo "檔案 $file 未被修改。"
    ;;
  r)
    echo "檔案將還原成官方檔案。"
    apt-get install --reinstall proxmox-widget-toolkit -y
    ;;
  *)
    echo "無效的選擇。"
    ;;
esac

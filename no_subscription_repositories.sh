#!/bin/bash
# https://pve.proxmox.com/wiki/Package_Repositories
# https://pve.proxmox.com/wiki/System_Software_Updates

# 定義 PVE 非訂閱套件庫
pve_no_subscription="deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription"

# 定義 Ceph 非訂閱套件庫
ceph_repos=(
  "deb http://download.proxmox.com/debian/ceph-quincy bookworm no-subscription"
  "deb http://download.proxmox.com/debian/ceph-reef bookworm no-subscription"
  "deb http://download.proxmox.com/debian/ceph-squid bookworm no-subscription"
)

# 清空 PVE 企業版套件庫
truncate -s 0 /etc/apt/sources.list.d/pve-enterprise.list

# 檢查 /etc/apt/sources.list 是否已包含非訂閱套件庫，若無則加入
if ! grep -q "$pve_no_subscription" /etc/apt/sources.list; then
  echo "$pve_no_subscription" >> /etc/apt/sources.list
fi

# 清空 ceph 套件庫後再寫入，確保只有非訂閱套件庫
truncate -s 0 /etc/apt/sources.list.d/ceph.list
for repo in "${ceph_repos[@]}"; do
  echo "$repo" >> /etc/apt/sources.list.d/ceph.list
done

# 更新套件庫清單
apt-get update

# 升級現有已安裝的套件及其需要的相依套件
apt-get dist-upgrade -y

# 清除更新時所下載回來的更新
apt-get clean

# 自動清除更新後用不到的舊版本檔案
apt-get autoremove -y

echo "完成！ No-Subscription 套件庫已成功設定並更新。"

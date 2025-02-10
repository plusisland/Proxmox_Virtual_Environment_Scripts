#!/usr/bin/env bash
# https://pve.proxmox.com/wiki/Package_Repositories
# https://pve.proxmox.com/wiki/System_Software_Updates

# 定義 PVE 非訂閱套件庫
pve_no_subscription="deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription"
ceph_quincy="deb http://download.proxmox.com/debian/ceph-quincy bookworm no-subscription"
ceph_reef="deb http://download.proxmox.com/debian/ceph-reef bookworm no-subscription"
ceph_squid="deb http://download.proxmox.com/debian/ceph-squid bookworm no-subscription"

# 清空 PVE 企業版套件庫
truncate -s 0 /etc/apt/sources.list.d/pve-enterprise.list

# 檢查 /etc/apt/sources.list 是否已包含非訂閱套件庫
if ! grep -q "$pve_no_subscription" /etc/apt/sources.list; then
  # 增加非訂閱套件庫
  echo "$pve_no_subscription" >> /etc/apt/sources.list
fi

# 清空 ceph 套件庫後再寫入，確保只有非訂閱套件庫
truncate -s 0 /etc/apt/sources.list.d/ceph.list
echo "$ceph_quincy" >> /etc/apt/sources.list.d/ceph.list
echo "$ceph_reef" >> /etc/apt/sources.list.d/ceph.list
echo "$ceph_squid" >> /etc/apt/sources.list.d/ceph.list

# 更新套件庫清單
apt-get update

# 升級現有已安裝的套件及其需要的相依套件
apt-get dist-upgrade -y  # 加入 -y 自動同意升級

# 清除更新時所下載回來的更新
apt-get clean

# 自動清除更新後用不到的舊版本檔案
apt-get autoremove -y # 加入 -y 自動同意移除

#!/usr/bin/env bash
# https://pve.proxmox.com/pve-docs/chapter-sysadmin.html#sysadmin_package_repositories

# 定義 PVE 非訂閱套件庫 | Define PVE no-subscription repository
pve_no_subscription="deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription"

# 定義 Ceph 非訂閱套件庫 | Define Ceph no-subscription repositories
ceph_repos=(
  "deb http://download.proxmox.com/debian/ceph-quincy bookworm no-subscription"
  "deb http://download.proxmox.com/debian/ceph-reef bookworm no-subscription"
  "deb http://download.proxmox.com/debian/ceph-squid bookworm no-subscription"
)

# 使用 echo 指令搭配重新導向符號 > 清空並寫入檔案，取代 truncate | Use echo with > to clear and write to file, replacing truncate
echo "" > /etc/apt/sources.list.d/pve-enterprise.list
echo "" > /etc/apt/sources.list.d/ceph.list

# 使用 grep -q 檢查是否已存在，若不存在則使用 echo 指令搭配 >> 加入 | Use grep -q to check if the repository already exists, if not, use echo with >> to add
grep -q "$pve_no_subscription" /etc/apt/sources.list || echo "$pve_no_subscription" >> /etc/apt/sources.list

# 迴圈遍歷 ceph_repos 陣列，將每個套件庫加入 ceph.list 檔案 | Loop through ceph_repos array and add each repository to ceph.list file
for repo in "${ceph_repos[@]}"; do
  echo "$repo" >> /etc/apt/sources.list.d/ceph.list
done

# 更新、升級、清除暫存檔案及移除不必要的舊版本檔案 | Update, upgrade, clean cache, and remove unnecessary old versions
apt-get update && apt-get dist-upgrade -y && apt-get clean && apt-get autoremove -y

# 完成訊息 | Completion message
echo "完成！No-Subscription 套件庫已成功設定並更新。 | Done! No-Subscription repositories have been successfully configured and updated."

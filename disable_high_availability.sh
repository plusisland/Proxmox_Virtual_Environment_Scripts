#!/usr/bin/env bash
# https://free-pmx.pages.dev/guides/ha-disable

# 永久停用 Proxmox High Availability (HA) 服務 | Disable Proxmox High Availability (HA) Service Permanently.
# 此腳本需在 Proxmox 集群的所有節點上執行。 | This script needs to be executed on all nodes in the Proxmox cluster.
# 停用 HA 服務代表高可用性虛擬機器將不再於主機故障時自動移轉至其他節點，可能導致停機。 | Disabling HA service means that high-availability virtual machines will no longer automatically failover to another node in case of host failure, which may cause downtime.
# 請務必了解後果，並確認不再需要 HA 功能後再執行。 | Please be sure to understand the consequences and confirm that you no longer need the HA function before executing.

# 1. 停止所有 HA 相關服務 (包含 corosync) | 1. Stop all HA related services (including corosync)
systemctl stop pve-ha-crm pve-ha-lrm watchdog-mux corosync

# 2. 屏蔽所有 HA 相關服務，防止開機時自動啟動 (包含 corosync) | 2. Mask all HA related services to prevent automatic startup at boot (including corosync)
systemctl mask pve-ha-crm pve-ha-lrm watchdog-mux corosync

# 3. 黑名單 softdog 核心模組，防止開機時載入 | 3. Blacklist the softdog kernel module to prevent loading at boot
cat > /etc/modprobe.d/softdog-deny.conf << EOF
blacklist softdog
install softdog /bin/false
EOF

echo "Proxmox HA 服務及 corosync 服務已永久停用。 | Proxmox HA service and corosync service have been permanently disabled."
echo "請在 Proxmox 集群中的所有其他節點上執行此腳本。 | Please execute this script on all other nodes in the Proxmox cluster."
echo "若要重新啟用 HA，需手動解除屏蔽所有服務並移除黑名單設定。 | To re-enable HA, you need to manually unmask all services and remove the blacklist configuration."

#!/usr/bin/env bash
# https://pve.proxmox.com/wiki/Package_Repositories

header_info() {
    clear
    cat <<"EOF"
        ____ _    ________   ____             __     ____           __        ____
       / __ \ |  / / ____/  / __ \____  _____/ /_   /  _/___  _____/ /_____ _/ / /
      / /_/ / | / / __/    / /_/ / __ \/ ___/ __/   / // __ \/ ___/ __/ __ `/ / /
     / ____/| |/ / /___   / ____/ /_/ (__  ) /_   _/ // / / (__  ) /_/ /_/ / / /
    /_/     |___/_____/  /_/    \____/____/\__/  /___/_/ /_/____/\__/\__,_/_/_/

EOF
}

RD=$(echo "\033[01;31m")
YW=$(echo "\033[33m")
GN=$(echo "\033[1;92m")
CL=$(echo "\033[m")
BFR="\\r\\033[K"
HOLD="-"
CM="${GN}✓${CL}"
CROSS="${RD}✗${CL}"

set -euo pipefail
shopt -s inherit_errexit nullglob

msg_info() {
    local msg="$1"
    echo -ne " ${HOLD} ${YW}${msg}..."
}

msg_ok() {
    local msg="$1"
    echo -e "${BFR} ${CM} ${GN}${msg}${CL}"
}

msg_error() {
    local msg="$1"
    echo -e "${BFR} ${CROSS} ${RD}${msg}${CL}"
}

start_routines() {
    header_info

    # 套件庫設定
    CHOICE=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "套件庫設定" --menu "是否設定套件庫：" 10 58 2 \
        "yes" "是" \
        "no" "否" 3>&2 2>&1 1>&3)

    case $CHOICE in
        yes)
            # 使用 checklist 讓使用者選擇要設定的套件庫
            CHECKLIST=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "選擇要設定的套件庫" --checklist "請選擇要設定的套件庫：" 16 70 3 \
                "ceph-enterprise" "停用 Ceph 企業版套件庫" OFF \
                "pve-enterprise" "停用 PVE 企業版套件庫" OFF \
                "pve-no-subscription" "啟用 PVE 非訂閱版套件庫" OFF 3>&2 2>&1 1>&3)

            # 根據使用者的選擇執行相應的操作
            for item in $CHECKLIST; do
                case $item in
                    ceph-enterprise)
                        msg_info "正在停用 Ceph 企業版套件庫"
                        cat <<EOF >/etc/apt/sources.list.d/ceph.list
# deb https://enterprise.proxmox.com/debian/ceph-quincy bookworm enterprise
EOF
                        msg_ok "已停用 Ceph 企業版套件庫"
                        ;;
                    pve-enterprise)
                        msg_info "正在停用 PVE 企業版套件庫"
                        cat <<EOF >/etc/apt/sources.list.d/pve-enterprise.list
# deb https://enterprise.proxmox.com/debian/pve bookworm pve-enterprise
EOF
                        msg_ok "已停用 PVE 企業版套件庫"
                        ;;
                    pve-no-subscription)
                        msg_info "正在啟用 PVE 非訂閱版套件庫"
                        cat <<EOF >/etc/apt/sources.list.d/pve-install-repo.list
deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription
EOF
                        msg_ok "已啟用 PVE 非訂閱版套件庫"
                        ;;
                esac
            done
            ;;
        no)
            msg_info "不做任何設定"
            ;;
    esac

    # 移除訂閱提示訊息
    if [[ ! -f /etc/apt/apt.conf.d/no-nag-script ]]; then
        CHOICE=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "移除訂閱提示訊息" --menu "是否移除" 14 58 2 \
            "yes" "是" \
            "no" "否" 3>&2 2>&1 1>&3)
        case $CHOICE in
            yes)
                msg_info "移除訂閱提示訊息"
                echo "DPkg::Post-Invoke { \"dpkg -V proxmox-widget-toolkit | grep -q '/proxmoxlib\.js$'; if [ \$? -eq 1 ]; then { echo 'Removing subscription nag from UI...'; sed -i '/.*data\.status.*{/{s/\!//;s/active/NoMoreNagging/}' /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js; }; fi\"; };" >/etc/apt/apt.conf.d/no-nag-script
                apt --reinstall install proxmox-widget-toolkit &>/dev/null
                msg_ok "已移除訂閱提示訊息"
                ;;
        esac
    fi

    CHOICE=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "高可用性設定" --menu "請選擇高可用性設定：" 14 58 3 \
        "yes" "啟用高可用性(多節點伺服器)" \
        "no" "停用高可用性(單節點伺服器)" 3>&2 2>&1 1>&3)

    case $CHOICE in
        yes)
            msg_info "正在啟用高可用性"
            systemctl enable -q --now pve-ha-lrm
            systemctl enable -q --now pve-ha-crm
            systemctl enable -q --now corosync
            msg_ok "已啟用高可用性"
            ;;
        no)
            msg_info "正在停用高可用性"
            systemctl disable -q --now pve-ha-lrm
            systemctl disable -q --now pve-ha-crm
            systemctl disable -q --now corosync
            msg_ok "已停用高可用性"
            ;;
    esac

    CHOICE=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "更新套件庫" --menu "\n立即更新?" 11 58 2 \
        "yes" "是" \
        "no" "否" 3>&2 2>&1 1>&3)
    case $CHOICE in
        yes)
            msg_info "更新速度受網路速度與硬體等級相關，請耐心等候..."
            apt-get update &>/dev/null
            apt-get -y dist-upgrade &>/dev/null
            msg_ok "更新完畢"
            ;;
    esac

    CHOICE=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "重新啟動" --menu "\n立刻重啟?" 11 58 2 \
        "yes" "是" \
        "no" "否" 3>&2 2>&1 1>&3)
    case $CHOICE in
        yes)
            msg_info "兩秒後重新啟動"
            sleep 2
            reboot
            ;;
    esac
}

header_info
echo -e "\nThis script will Perform Post Install Routines.\n"
while true; do
    read -p "Start the Proxmox VE Post Install Script (y/n)?" yn
    case $yn in
        [Yy]*) break ;;
        [Nn]*) clear; exit ;;
        *) echo "Please answer yes or no." ;;
    esac
done

if ! pveversion | grep -Eq "pve-manager/8\.[0-3](\.[0-9]+)*"; then
  msg_error "This version of Proxmox Virtual Environment is not supported"
  echo -e "Requires Proxmox Virtual Environment Version 8.0 or later."
  echo -e "Exiting..."
  sleep 2
  exit
fi

start_routines

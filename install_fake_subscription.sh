#!/usr/bin/env bash
# https://github.com/Jamesits/pve-fake-subscription/tree/master

deb_url="https://github.com/Jamesits/pve-fake-subscription/releases/download/v0.0.11/pve-fake-subscription_0.0.11+git-1_all.deb"

read -p "要安裝 pve-fake-subscription 嗎？(y安裝/n取消/u移除): " choice

case "$choice" in
  y)
    wget -q https://github.com/Jamesits/pve-fake-subscription/releases/download/v0.0.11/pve-fake-subscription_0.0.11+git-1_all.deb
    dpkg -i pve-fake-subscription_*.deb
    rm -rf pve-fake-subscription_*.deb
    #echo "127.0.0.1 shop.maurer-it.com" | sudo tee -a /etc/hosts
    ;;
  n)
    echo "檔案 $file 未被修改。"
    ;;
  u)
    apt purge pve-fake-subscription
    ;;
esac

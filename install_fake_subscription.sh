#!/usr/bin/env bash
# https://github.com/Jamesits/pve-fake-subscription/tree/master

read -p "要安裝 pve-fake-subscription 嗎？(y安裝/n取消/u移除): " choice

case "$choice" in
  y)
    curl -fL "$(curl -fsS https://api.github.com/repos/Jamesits/pve-fake-subscription/releases/latest | sed -r -n 's/.*"browser_download_url": *"(.*\.deb)".*/\1/p')" -O
    dpkg -i pve-fake-subscription_*.deb
    rm -rf pve-fake-subscription_*.deb
    #echo "127.0.0.1 shop.maurer-it.com" | sudo tee -a /etc/hosts
    ;;
  n)
    echo "取消安裝。"
    ;;
  u)
    echo "移除安裝。"
    apt purge pve-fake-subscription
    ;;
esac

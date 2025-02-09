1.修改顯示狀態
```
bash -c "$(wget -qLO - https://raw.githubusercontent.com/plusisland/-Proxmox/refs/heads/main/Proxmox_VE_Change_Status.sh)"
```
2.PCIe設備直通
```
bash -c "$(wget -qLO - https://raw.githubusercontent.com/plusisland/-Proxmox/refs/heads/main/PCI_Passthrough.sh)"
```
3.OpenWrt建立
```
bash -c "$(wget -qLO - https://raw.githubusercontent.com/plusisland/-Proxmox/refs/heads/main/OpenWrt.sh)"
```
#更新清單

opkg update

#安裝中文化

opkg install luci-i18n-base-zh-tw

#安裝pcie

opkg install pciutils

#安裝驅動

opkg install kmod-mt7921e

#安裝藍芽

opkg install mt7922bt-firmware

#安裝韌體

opkg install kmod-mt7922-firmware

#安裝 wpa-supplicant

opkg install wpa-supplicant

#安裝 hostapd

opkg install hostapd

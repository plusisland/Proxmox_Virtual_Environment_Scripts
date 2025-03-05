## 軟體版本資訊

| 軟體           | 版本     | 基礎系統 | 核心版本 | 網址                                                                 |
|:--------------:|:--------:|:--------:|:--------:|:--------------------------------------------------------------------:|
| pfSense        | 2.7.2    | FreeBSD  | 14.2     | [pfSense版本資訊](https://docs.netgate.com/pfsense/en/latest/releases/versions.html) |
| OPNsense       | 24.7     | FreeBSD  | 14.1     | [OPNsense版本資訊](https://www.thomas-krenn.com/en/wiki/OPNsense_Release_Information) |
| OpenWrt        | 24.1     | Linux    | 6.6      | [OpenWrt核心版本](https://openwrt.org/docs/techref/targets/kernelversions) |
| Ubuntu         | 22.04    | Linux    | 6.8      | [Ubuntu核心生命周期](https://ubuntu.com/kernel/lifecycle) |
| Debian         | 12.9     | Linux    | 6.12     | [Debian版本歷史](https://en.wikipedia.org/wiki/Debian_version_history) |
| Proxmox VE     | 8.3-1    | Linux    | 6.8      | [Proxmox VE核心版本](https://pve.proxmox.com/wiki/Proxmox_VE_Kernel) |
| Home Assistant | 14.2     | Linux    | 6.673    | [Home Assistant版本資訊](https://github.com/home-assistant/operating-system/releases) |

---

## Wifi 無線網路卡支援查詢

| 基礎系統  | Intel                                                                                               | MediaTek                                                                                              | Realtek                                                                                                  |
|:--------:|:---------------------------------------------------------------------------------------------------:|:----------------------------------------------------------------------------------------------------:|:--------------------------------------------------------------------------------------------------------:|
| FreeBSD  | [Iwlwifi](https://wiki.freebsd.org/WiFi/Iwlwifi)                                                     | [Mt76](https://wiki.freebsd.org/WiFi/Mt76)                                                            | [Rtw89](https://wiki.freebsd.org/WiFi/Rtw89)                                                             |
| Linux    | [Iwlwifi](https://wireless.docs.kernel.org/en/latest/en/users/drivers/iwlwifi.html)                  | [MediaTek](https://wireless.docs.kernel.org/en/latest/en/users/drivers/mediatek.html)                 | [Realtek](https://wireless.docs.kernel.org/en/latest/en/users/drivers/rtl819x.html)                       |
| OpenWrt  | [kmod-iwlwifi](https://downloads.openwrt.org/releases/24.10.0/targets/x86/64/kmods/6.6.73-1-a21259e4f338051d27a6443a3a7f7f1f) | [kmod-mt79](https://downloads.openwrt.org/releases/24.10.0/targets/x86/64/kmods/6.6.73-1-a21259e4f338051d27a6443a3a7f7f1f) | [kmod-rtw89](https://downloads.openwrt.org/releases/24.10.0/targets/x86/64/kmods/6.6.73-1-a21259e4f338051d27a6443a3a7f7f1f) |

---

## 支援Wi-Fi無線網路卡設備

若要同時支援 OpenWrt、Windows、Proxmox VE 系統，您可考慮以下Wi-Fi設備：

- Wi-Fi 6E Intel Wi-Fi 6E AX210 (5.1)
- Wi-Fi 6 Intel Wi-Fi 6 AX200 (5.1)
- Wi-Fi 6E MediaTek MT7921/MT7922 (5.9)
- Wi-Fi 6 MediaTek MT7915/MT7916 (5.16)
- Wi-Fi 6E Realtek RTL8852CE (6.1) Not support FreeBSD
- Wi-Fi 6 Realtek RTL8852BE (6.1) Not support FreeBSD

這些設備能夠提供更高效的無線連接，並支持各大作業系統。

https://www.right.com.cn/forum/thread-8307497-1-1.html

https://github.com/morrownr/USB-WiFi/blob/main/home/PCIe_WiFi_Devices.md

https://github.com/morrownr/USB-WiFi/blob/main/home/How_to_Install_Firmware_for_Mediatek_based_USB_WiFi_adapters.md

https://github.com/lwfinger/rtw89

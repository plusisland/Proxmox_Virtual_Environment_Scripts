#!/usr/bin/env bash
# https://openwrt.org/docs/guide-user/virtualization/qemu?s[]=proxmox#openwrt_in_qemu_x86-64

# 腳本描述：在 Proxmox VE 中自動創建 OpenWrt 虛擬機

# === 變數設定 (使用者可自訂) ===
VM_ID=101          # 虛擬機 ID (請確保 ID 未被使用)
VM_NAME="OpenWrt-Router" # 虛擬機名稱
VM_STORAGE="local-lvm"    # 虛擬機儲存位置 (例如 local, local-lvm, your_storage_name)
VM_DISK_SIZE="1G"       # 虛擬硬碟大小 (例如 512M, 1G, 2G)
VM_MEMORY="512"         # 記憶體大小 (MB)
VM_CPUS="1"           # CPU 核心數量
VM_NET_BRIDGE="vmbr0"   # 網路橋接介面 (請根據 Proxmox 環境修改)
OPENWRT_VERSION="23.05" # 指定 OpenWrt 版本 (例如 23.05, 22.03，或留空抓取最新穩定版)

# === 腳本設定 (一般情況下無需修改) ===
TARGET_ARCH="x86/64"
IMAGE_TYPE="generic-ext4-combined-efi"
DOWNLOAD_URL_BASE="https://downloads.openwrt.org/releases"
IMAGE_FILE_EXTENSION="img.gz"
IMAGE_FILENAME_BASE="openwrt-${OPENWRT_VERSION}-${TARGET_ARCH}-${IMAGE_TYPE}"
IMAGE_FILENAME_GZ="${IMAGE_FILENAME_BASE}.${IMAGE_FILE_EXTENSION}"
IMAGE_FILENAME="${IMAGE_FILENAME_BASE}.${IMAGE_FILE_EXTENSION%.*}"
IMG_PATH="${IMAGE_FILENAME}"

# === 函數定義 ===
error_exit() {
  echo "錯誤: $1" >&2
  exit 1
}

check_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    error_exit "指令 '$1' 未安裝，請先安裝。"
  fi
}

# === 檢查必要指令 ===
check_command curl
check_command wget
check_command gunzip
check_command qemu-img
check_command losetup
check_command parted
check_command qm

# === 抓取 OpenWrt 版本號 (如果未指定) ===
if [ -z "$OPENWRT_VERSION" ]; then
  echo "資訊: 未指定 OpenWrt 版本，嘗試抓取最新穩定版..."
  response=$(curl -s "https://openwrt.org/")
  if [[ "$response" =~ "Current stable release - OpenWrt ([0-9.]+)" ]]; then
    OPENWRT_VERSION="${BASH_REMATCH[1]}"
    IMAGE_FILENAME_BASE="openwrt-${OPENWRT_VERSION}-${TARGET_ARCH}-${IMAGE_TYPE}"
    IMAGE_FILENAME_GZ="${IMAGE_FILENAME_BASE}.${IMAGE_FILE_EXTENSION}"
    IMAGE_FILENAME="${IMAGE_FILENAME_BASE}.${IMAGE_FILE_EXTENSION%.*}"
    IMG_PATH="${IMAGE_FILENAME}"
    echo "資訊: 最新穩定版為 OpenWrt ${OPENWRT_VERSION}"
  else
    error_exit "無法從 openwrt.org 抓取最新版本號，請手動設定 OPENWRT_VERSION 變數。"
  fi
else
  echo "資訊: 使用指定的 OpenWrt 版本: ${OPENWRT_VERSION}"
fi

# === 建立下載 URL ===
DOWNLOAD_URL="${DOWNLOAD_URL_BASE}/${OPENWRT_VERSION}/targets/${TARGET_ARCH}/${IMAGE_FILENAME_GZ}"

echo "資訊: 下載 OpenWrt 映像檔: ${DOWNLOAD_URL}"

# === 下載 OpenWrt 映像檔 ===
wget --show-progress "$DOWNLOAD_URL" || error_exit "下載映像檔失敗。"

# === 解壓縮 OpenWrt 映像檔 ===
echo "資訊: 解壓縮映像檔: ${IMAGE_FILENAME_GZ}"
gunzip -f "$IMAGE_FILENAME_GZ" || error_exit "解壓縮映像檔失敗。"

# === 調整硬碟大小 ===
echo "資訊: 調整虛擬硬碟大小為: ${VM_DISK_SIZE}"
qemu-img resize -f raw "$IMAGE_FILENAME" "$VM_DISK_SIZE" || error_exit "調整硬碟大小失敗。"

# === 處理分割區 (調整第二分割區大小) ===
echo "資訊: 調整分割區大小..."
loop_device=$(losetup -f)
losetup "$loop_device" "$IMAGE_FILENAME" || error_exit "建立 loop device 失敗。"

if ! parted -s "$loop_device" print > /dev/null 2>&1; then
  losetup -d "$loop_device"
  error_exit "讀取分割區資訊失敗。"
fi

if ! parted -s "$loop_device" resizepart 2 100%; then
  losetup -d "$loop_device"
  error_exit "調整分割區大小失敗。"
fi

losetup -d "$loop_device" || error_exit "解除 loop device 失敗。"
echo "資訊: 分割區大小調整完成。"

# === 創建 Proxmox 虛擬機 ===
echo "資訊: 創建 Proxmox 虛擬機，ID: ${VM_ID}, 名稱: ${VM_NAME}"
qm create "$VM_ID" --name "$VM_NAME" --memory "$VM_MEMORY" --cores "$VM_CPUS" --net0 virtio,bridge="${VM_NET_BRIDGE}" --machine q35 --bios ovmf -onboot 1 -ostype other --scsihw virtio-scsi-pci || error_exit "創建虛擬機失敗。"

# === 匯入 OpenWrt 映像檔為虛擬硬碟 ===
echo "資訊: 匯入 OpenWrt 映像檔為虛擬硬碟..."
qm importdisk "$VM_ID" "$IMG_PATH" "$VM_STORAGE" || error_exit "匯入虛擬硬碟失敗。"

# === 設定虛擬機硬碟為主磁碟並設定開機順序 ===
echo "資訊: 設定虛擬機硬碟為主磁碟並設定開機順序..."
qm set "$VM_ID" --scsi0 "$VM_STORAGE":"vm-${VM_ID}-disk-0" --boot order=scsi0 || error_exit "設定虛擬機硬碟為主磁碟失敗。"

# 啟動虛擬機
echo "資訊: 啟動虛擬機..."
qm start "$VM_ID" || error_exit "啟動虛擬機失敗。"

# 顯示虛擬機狀態
qm status "$VM_ID"

echo "資訊: OpenWrt 虛擬機 (ID: ${VM_ID}, 名稱: ${VM_NAME}) 創建完成！"
echo "資訊: 您現在可以進行設定。"

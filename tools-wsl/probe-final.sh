#!/bin/bash
set -u
WS=/home/unixnu/code/umi-work-pin
FAT=$WS/out/umi/xnu/umi-xnu-fat.img
U=/home/unixnu/code/uefi-umi-b/Build/umiPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd
LOG=/mnt/e/Code/HackIos/out/verify-menu-xnu.log
tr -d '\r' < /mnt/e/Code/HackIos/tools-wsl/verify-menu-xnu.py > /tmp/vf.py
python3 /tmp/vf.py > "$LOG" 2>&1
{
  echo "=== FD 内 DarwinBoot 痕迹"
  strings -a "$U" | grep -i -m 10 darwin
  echo "=== 卷内 unixnu.toml"
  mtype -i "$FAT" ::EFI/UniXNU/unixnu.toml
} >> "$LOG" 2>&1

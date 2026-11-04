#!/bin/bash
set -u
U=/home/unixnu/code/uefi-umi-b
B=$U/Build/umiPkg/DEBUG_CLANGPDB
LOG=/mnt/e/Code/HackIos/out/probes/darwinboot-in-fd.txt
{
  echo "== 1. Build 树里的 DarwinBoot 产物"
  find "$B/AARCH64" -iname '*DarwinBoot*' | head -20
  echo "== 2. FV/Ffs 目录里的 DarwinBoot FFS"
  ls "$B/FV/Ffs" 2>/dev/null | grep -i -E 'darwin|Boot' | head -20
  echo "== 3. FD 中的 Unicode 字符串（UTF-16LE）"
  strings -a -el "$B/FV/SILICIUM_UEFI.fd" | grep -i -m 20 darwin
  echo "== 4. DarwinBoot.efi 的 PE 时间戳/尺寸 与 FFS 对比"
  ls -la "$B/AARCH64/DarwinBootPkg/DarwinBoot/DarwinBoot/OUTPUT/" 2>/dev/null | head
  echo "== 5. umi.dsc 里是否有 DarwinBoot"
  grep -rn -i 'darwinboot' "$U/Platform/Xiaomi/umiPkg/umi.dsc" "$U/Platform/Xiaomi/umiPkg/Include/"*.inc 2>/dev/null | head
  echo "== 6. 打包侧：Ffs 里 GUID 目录名"
  ls "$B/FV/Ffs" 2>/dev/null | wc -l
} > "$LOG" 2>&1

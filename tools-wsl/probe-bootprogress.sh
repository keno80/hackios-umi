#!/bin/bash
set -u
WS=/home/unixnu/code/umi-work-pin
LOG=/mnt/e/Code/HackIos/out/bootprogress.txt
{
  echo "== boot-progress 目录"
  ls -la "$WS/devices/umi/package/boot-progress/"
  echo "== BootProgress.c 全文"
  cat "$WS/devices/umi/package/boot-progress/BootProgress.c"
  echo "== 相关头/说明"
  ls "$WS/devices/umi/package/" | head -30
  echo "== trace 解码工具"
  ls "$WS/devices/umi/tools/" 2>/dev/null | grep -i trace | head
  echo "== 谁引用 BootProgress"
  grep -rln 'BootProgress' "$WS/devices/umi" "$WS/sources/UniXNU/drivers/DarwinBoot" 2>/dev/null | head -12
} > "$LOG" 2>&1

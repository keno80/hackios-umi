#!/bin/bash
set -u
WS=/home/unixnu/code/umi-work-pin
LOG=/mnt/e/Code/HackIos/out/bootprogress-kit.txt
K=$WS/out/umi-xnu/umi/kernel/source-kernel.macho
{
  echo "== 1. 我们的源码内核里有没有 boot_progress 符号"
  for s in boot_progress_init boot_progress_bind boot_progress_stage boot_progress_putc umi_boot_progress_record; do
    printf "  %-28s " "$s"
    aarch64-linux-gnu-nm "$K" 2>/dev/null | grep -c " $s\$" || true
  done
  echo "  (nm 不可用则用 strings 兜底)"
  strings -a "$K" | grep -c 'boot_progress' 2>/dev/null
  echo "== 2. 内核里的相关字符串"
  strings -a "$K" | grep -i -m 12 -E 'boot-progress|boot_progress|UniXNU boot diagnostics'
  echo "== 3. Kit.toml"
  cat "$WS/devices/umi/package/Kit.toml"
  echo "== 4. 作者的 XNU payload 配置（内核参数与 kits）"
  cat "$WS/devices/umi/package/unixnu-xnu.toml"
  echo "== 5. build-boot-progress.py 前 60 行"
  sed -n '1,60p' "$WS/devices/umi/scripts/build-boot-progress.py"
} > "$LOG" 2>&1

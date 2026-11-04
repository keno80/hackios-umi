#!/bin/bash
# R 步之一：真机屏上出现 `zalloc.c:777 ... VM map entries[16] ... invalid zidx: 64`，
# 同一份内核在 QEMU 里能一路跑到 EL0，差别必须先归因，不能凭猜改参数。
# 本脚本只做取证：菜单实际带的启动参数 + zalloc.c:777 原文 + kt_fixed_zones 在内核里到底动什么。
set -u
LOG=/mnt/e/Code/HackIos/out/probes/r1-zidx-panic.txt
: > "$LOG"
exec >>"$LOG" 2>&1

W=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi
X=$W/tree/.cache/xnu-work
FAT=/home/unixnu/code/umi-work-pin/out/umi/xnu/umi-xnu-fat.img

echo "== 1. 真机菜单里 xnu 条目实际带的 args（不是 QEMU 脚本里的 --args）=="
if [ -f "$FAT" ]; then
  ls -la "$FAT" | sed 's#^# #'
  mkdir -p /tmp/r1 && rm -f /tmp/r1/unixnu.toml
  mcopy -o -n -s -i "$FAT" ::/EFI/UniXNU/unixnu.toml /tmp/r1/ 2>/dev/null || \
    mcopy -o -i "$FAT" ::/EFI/UniXNU/unixnu.toml /tmp/r1/ 2>/dev/null
  if [ -f /tmp/r1/unixnu.toml ]; then
    grep -nE '^\[|args|title|path' /tmp/r1/unixnu.toml
  else
    echo "!! 取不到 unixnu.toml，改从卷里直接抠字符串"
    strings -a "$FAT" | grep -n 'kt_fixed_zones\|keepsyms' | head
  fi
else
  echo "!! $FAT 不存在"
fi
echo

echo "== 2. zalloc.c:777 附近原文 =="
Z=$(ls "$X"/os/zalloc.c "$X"/vm/zalloc.c "$X"/*/zalloc.c 2>/dev/null | head -1)
[ -f "$Z" ] || { echo "!! 找不到 zalloc.c"; }
if [ -n "${Z:-}" ]; then
  echo "路径：$Z"
  awk 'NR>=735 && NR<=790 {printf "%4d  %s\n", NR, $0}' "$Z"
  echo "-- 该 panic 语句所在函数名 --"
  awk -v n=777 'NR<=n && /^[a-zA-Z_].*\(/{f=$0} END{print f}' "$Z"
fi
echo

echo "== 3. kt_fixed_zones 在内核里动的是什么 =="
grep -rn "kt_fixed_zones" "$X" --include=*.c --include=*.h 2>/dev/null | head -20
echo

echo "== 4. zidx 校验链：zone 索引从哪来、什么时候算 invalid =="
if [ -n "${Z:-}" ]; then
  grep -n "invalid zidx\|z_chunk_meta\|zone_page_meta\|zid_zone_ref_t\|zidx" "$Z" | head -30
fi
echo

echo "== 5. VM map entries 这个 zone 的静态槽位（编号是否 <120）=="
grep -rn "VM map entries" "$X" --include=*.c --include=*.h 2>/dev/null | head -10
echo "== done $(date -u +%FT%TZ)"

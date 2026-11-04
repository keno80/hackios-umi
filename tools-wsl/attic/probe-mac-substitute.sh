#!/bin/bash
set -u
OUT=/mnt/e/Code/HackIos/out/probes/mac-substitute.txt
: > "$OUT"
say() { printf '%s\n' "$*" >> "$OUT"; }
S=/home/unixnu/code/UniXNU-main
T=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree

say "== 1. xcrun shim 全文（看它怎么转发 dwarfdump）=="
cat /usr/bin/xcrun >> "$OUT" 2>&1

say
say "== 2. 真 SDKROOT 在哪、有没有 TargetConditionals.h =="
env | grep -i 'UNIXNU_SDKROOT\|SDKROOT' >> "$OUT" 2>&1
grep -rn 'UNIXNU_SDKROOT' "$S/scripts"/*.py 2>/dev/null | head -8 >> "$OUT"
say "-- 全机器搜 TargetConditionals.h --"
timeout 60 find /opt/unixnu-linux /home/unixnu/code/UniXNU-main/drivers -name 'TargetConditionals.h' 2>/dev/null | head -5 >> "$OUT"

say
say "== 3. mkapfs 能造出 Apple 能读的东西吗（先看它的实现范围）=="
/usr/sbin/mkapfs 2>&1 | head -10 >> "$OUT"
say "-- apfs-snap 是干什么的 --"
test -f /usr/share/man/man8/apfs-snap.8.gz && zcat /usr/share/man/man8/apfs-snap.8.gz | head -25 >> "$OUT"
dpkg -L apfsprogs | grep -E 'sbin|share/man' >> "$OUT"

say
say "== 4. OS 卷在 Linux 上解到哪了（make-data-seed 的 os_mount 输入）=="
find /home/unixnu/code/umi-work-pin/out -maxdepth 6 -type d -name 'System*' 2>/dev/null | head -10 >> "$OUT"
ls /home/unixnu/code/umi-work-pin/out/umi-xnu/ipsw/*/ 2>/dev/null | head -20 >> "$OUT"
say "-- 有没有已解出的 OS.dmg 原始盘 --"
find /home/unixnu/code/umi-work-pin/out -maxdepth 7 -name '*.dmg' -o -maxdepth 7 -name 'userdata-root.img' 2>/dev/null | head -10 >> "$OUT"
say done

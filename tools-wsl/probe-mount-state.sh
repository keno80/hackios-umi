#!/bin/bash
set -u
OUT=/mnt/e/Code/HackIos/out/probes/f-mount.txt
: > "$OUT"
say() { printf '%s\n' "$*" >> "$OUT"; }
say "== devices 里到底有什么 =="
ls -la /home/unixnu/code/umi-work-pin/devices/ >> "$OUT" 2>&1
say "-- devices/umi 是符号链接吗 --"
stat -c '%F %n -> %N' /home/unixnu/code/umi-work-pin/devices/umi >> "$OUT" 2>&1
readlink -f /home/unixnu/code/umi-work-pin/devices/umi >> "$OUT" 2>&1
ls -la /home/unixnu/code/umi-work-pin/devices/umi/ >> "$OUT" 2>&1
say
say "== 当前所有非内核挂载 =="
grep -E "ext4|drvfs|bind|9p|/mnt/|/home" /proc/mounts | head -20 >> "$OUT" 2>&1
say
say "== /etc/fstab（有没有开机自动挂载）=="
cat /etc/fstab >> "$OUT" 2>&1
say
say "== 磁盘 =="
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT 2>&1 | head -15 >> "$OUT"
say "-- /data 之类的挂载点 --"
ls -la / 2>&1 | grep -E "^d" | head -20 >> "$OUT"
say done

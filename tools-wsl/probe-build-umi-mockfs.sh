#!/bin/bash
set -u
OUT=/mnt/e/Code/HackIos/out/probes/umi-build-umi-xnu-mockfs.txt
: > "$OUT"
say() { printf '%s\n' "$*" >> "$OUT"; }
F=/home/unixnu/code/umi-work-pin/tools/build_umi_xnu.py
say "== 120..175（settings 与 data_input）=="
sed -n '120,175p' "$F" >> "$OUT" 2>&1
say
say "== 270..330（archives 与 original-mockfs）=="
sed -n '270,330p' "$F" >> "$OUT" 2>&1
say
say "== data_input / data_ramdisk 全部引用 =="
grep -n 'data_input\|data_ramdisk\|data-ramdisk\|MOCKFS\|mockfs' "$F" >> "$OUT" 2>&1
say
say "== 三份 defconfig 是否同一 inode =="
for p in /home/unixnu/code/UniXNU-umi /home/unixnu/code/umi-work-pin/devices/umi /mnt/e/Code/HackIos/UniXNU-umi; do
  say "$p -> $(stat -c '%d:%i %s %y' "$p/configs/umi_defconfig" 2>&1)"
done
say "-- /home/unixnu/code 挂载 --"
findmnt -no SOURCE,TARGET,FSTYPE /home/unixnu/code 2>&1 >> "$OUT"
findmnt -no SOURCE,TARGET,FSTYPE --target /home/unixnu/code/UniXNU-umi 2>&1 >> "$OUT"
findmnt -no SOURCE,TARGET,FSTYPE --target /home/unixnu/code/umi-work-pin/devices/umi 2>&1 >> "$OUT"
say
say "== profiles/arch/arm64/profile.toml 的 archives 段 =="
sed -n '1,40p' /home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/profiles/arch/arm64/profile.toml >> "$OUT" 2>&1
find /home/unixnu/code/umi-work-pin -maxdepth 5 -name profile.toml -path '*arm64*' 2>/dev/null >> "$OUT"
say done

#!/bin/bash
set -u
OUT=/mnt/e/Code/HackIos/out/probes/darwinboot-initrd.txt
: > "$OUT"
say() { printf '%s\n' "$*" >> "$OUT"; }
S=/home/unixnu/code/UniXNU-main
DB=$S/drivers/DarwinBoot

say "== 1. DarwinBoot 里 initrd 的全部出现处 =="
grep -rn 'initrd\|Initrd\|INITRD' "$DB" 2>/dev/null | grep -v Binary | head -30 >> "$OUT"

say
say "== 2. RAMDisk 属性填写段（DarwinBoot.c 280-360）=="
sed -n '280,360p' "$DB/DarwinBootPkg/Driver/DarwinBoot.c" >> "$OUT" 2>&1

say
say "== 3. native-fp-context / apfs-checkpoints 里的挂根判据 =="
grep -n 'mockfs\|md0\|ramdisk\|mount root\|RAMDisk' "$S/scripts/check-native-fp-context.py" 2>/dev/null | head -20 >> "$OUT"
echo "---" >> "$OUT"
grep -n 'mockfs\|md0\|RAMDisk\|root' "$S/scripts/check-original-apfs-checkpoints.py" 2>/dev/null | head -20 >> "$OUT"

say
say "== 4. native-apfs-launchd.inc（mockfs 相关）=="
grep -n 'mockfs\|launchd\|sbin\|root' "$S/scripts/qemu-entry/native-apfs-launchd.inc" 2>/dev/null | head -25 >> "$OUT"

say
say "== 5. probe-darwinboot-xnu.py 里 root.img 之后的启动参数（400-430）=="
sed -n '400,430p' "$S/scripts/probe-darwinboot-xnu.py" >> "$OUT" 2>&1
say done

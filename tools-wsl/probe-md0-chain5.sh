#!/bin/bash
set -u
OUT=/mnt/e/Code/HackIos/out/probes/md0-chain5.txt
: > "$OUT"
say() { printf '%s\n' "$*" >> "$OUT"; }
W=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
T=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree

say "== 1. bsd_init.c 1325..1365（setconf 里的 IOFindBSDRoot 与 rootdev=makedev(6,0) 回退）=="
sed -n '1325,1365p' "$W/bsd/kern/bsd_init.c" >> "$OUT" 2>&1

say
say "== 2. IOKitBSDInit.cpp 860..935（rd=md0 解析与 panic 分支）=="
sed -n '860,935p' "$W/iokit/bsddev/IOKitBSDInit.cpp" >> "$OUT" 2>&1

say
say "== 3. CONFIG_MEMDEV_INSECURE 定义点 =="
grep -rn 'CONFIG_MEMDEV_INSECURE' "$W" 2>/dev/null | grep -v '\.o:' | head -15 >> "$OUT"
say "-- memdev.c 的编译归属（bsd/Makefile）--"
grep -n 'memdev' "$W/bsd/Makefile" >> "$OUT" 2>&1

say
say "== 4. 当前内核里 memdev 与 mockfs 符号实况 =="
K=$T/build/xnu/ios-obj/DEVELOPMENT_ARM64_BCM2837/mach.development.bcm2837.unstripped.noctf
NM=/opt/unixnu-linux/llvm/bin/llvm-nm
say "-- memdev 相关（前 12 条）--"
$NM "$K" 2>/dev/null | grep -i 'mdev' | head -12 >> "$OUT"
say "-- mockfs 相关 --"
$NM "$K" 2>/dev/null | grep -i mockfs | head -12 >> "$OUT"
say "-- memdev.o 是否真的产出 --"
ls -l "$T/build/xnu/ios-obj/DEVELOPMENT_ARM64_BCM2837/bsd/DEVELOPMENT/memdev.o" 2>&1 >> "$OUT"
say "-- dev_t makedev(6,0) 对应的主设备 --"
grep -rn 'D_MD\|"md"' "$W/bsd/dev/conf.c" 2>/dev/null | head -5 >> "$OUT"

say
say "== 5. UniXNURamDiskDxe / RAMDisk 在 uefi-umi 侧是否存在 =="
find /home/unixnu/code -maxdepth 7 -iname '*RamDisk*' 2>/dev/null | grep -vi '\.git/' | head -20 >> "$OUT"
say done

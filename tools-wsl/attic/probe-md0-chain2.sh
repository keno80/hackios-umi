#!/bin/bash
set -u
OUT=/mnt/e/Code/HackIos/out/probes/md0-chain2.txt
: > "$OUT"
say() { printf '%s\n' "$*" >> "$OUT"; }
T=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree
W=$T/.cache/xnu-work

say "== 0. WSL 设备仓 vs Windows 设备仓差异 =="
diff /home/unixnu/code/UniXNU-umi/configs/umi_defconfig /mnt/e/Code/HackIos/UniXNU-umi/configs/umi_defconfig >> "$OUT" 2>&1
say "-- board.toml 差异（前 40 行 diff）--"
diff /home/unixnu/code/UniXNU-umi/board.toml /mnt/e/Code/HackIos/UniXNU-umi/board.toml 2>&1 | head -40 >> "$OUT"

say
say "== A. IOKitBSDInit.cpp 780..830（rd 解析）=="
sed -n '780,830p' "$W/iokit/bsddev/IOKitBSDInit.cpp" >> "$OUT" 2>&1
say "== A2. IOKitBSDInit.cpp 930..975（选根循环入口）=="
sed -n '930,975p' "$W/iokit/bsddev/IOKitBSDInit.cpp" >> "$OUT" 2>&1

say
say "== B. bsd_init.c 里 RAMDisk / initrd / PE_RamDisk 引用 =="
grep -n 'RAMDisk\|ramdisk\|initrd\|PE_RamDisk\|memory-map\|create_memdev\|md0' "$W/bsd/kern/bsd_init.c" >> "$OUT" 2>&1

say
say "== C. memdev.c：create_memdev 与注册入口 =="
grep -n 'create_memdev\|^memdev\|d_type\|devsw\|md%d\|mi_mdev\|DKIOCGETMEMDEVINFO' "$W/bsd/dev/memdev.c" >> "$OUT" 2>&1
say "-- create_memdev 函数体 --"
awk '/^create_memdev/,/^}/' "$W/bsd/dev/memdev.c" | head -60 >> "$OUT" 2>&1
say "-- 谁调用 create_memdev（全树）--"
grep -rn 'create_memdev' "$W" 2>/dev/null | grep -v '\.o:' | head -20 >> "$OUT"

say
say "== D. mountroot 候选如何被 vfs_mountroot 遍历（rootmount 相关）=="
grep -n 'vfc_mountroot\|vfs_mountroot_try\|mountroot_once\|vfs_mountroot_with_args\|rootfilevp' "$W/bsd/vfs/vfs_kglue.c" "$W/bsd/vfs/vfs_subr.c" 2>/dev/null | head -30 >> "$OUT"
say "-- vfs_mountroot 主体 --"
grep -rn 'vfs_mountroot(' "$W/bsd/vfs/vfs_subr.c" >> "$OUT" 2>&1
say done

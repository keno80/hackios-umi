#!/bin/bash
set -u
OUT=/mnt/e/Code/HackIos/out/probes/md0-chain4.txt
: > "$OUT"
say() { printf '%s\n' "$*" >> "$OUT"; }
W=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work

say "== 1. memdev.c 483..548（mdevinit 与 mdev= 引导参数）=="
sed -n '483,548p' "$W/bsd/dev/memdev.c" >> "$OUT" 2>&1

say
say "== 2. mdevinit 的调用者（全树）=="
grep -rn 'mdevinit' "$W" 2>/dev/null | grep -v '\.o:' | head -20 >> "$OUT"
say "-- 'mdev=' 引导参数字符串 --"
grep -rn '"mdev"' "$W" 2>/dev/null | head -10 >> "$OUT"

say
say "== 3. rootdev 的赋值点 =="
grep -rn 'cpu_set_rootdev' "$W/bsd" "$W/iokit" "$W/libsa" 2>/dev/null | grep -v '\.o:' | head -20 >> "$OUT"
say "-- bsd_init.c 中 rootdev/rootdevice 设置 --"
grep -n 'rootdev\b\|rootdevice\[' "$W/bsd/kern/bsd_init.c" | head -30 >> "$OUT"

say
say "== 4. bsd_init 何时调 IOFFindBSDRoot / di_root_ramfile =="
grep -rn 'IOFindBSDRoot\|di_root_ramfile' "$W/bsd/kern/bsd_init.c" "$W/iokit/bsddev/IOKitBSDInit.cpp" "$W/libsa/bootstrap.cpp" 2>/dev/null | head -20 >> "$OUT"
say "-- IOKitBSDInit.cpp 中 di_root_ramfile 定义 --"
grep -n 'di_root_ramfile' -A 30 "$W/iokit/bsddev/IOKitBSDInit.cpp" | head -60 >> "$OUT"

say
say "== 5. libsa/bootstrap.cpp 里 IORamDiskBSDRoot 的使用上下文 =="
grep -n 'IORamDiskBSDRoot' -B 15 -A 25 "$W/libsa/bootstrap.cpp" >> "$OUT" 2>&1

say
say "== 6. devfs 何时建立（md0 节点依赖）=="
grep -rn 'vfs_root_mount_devfs\|devfs_make_node\|kOSSecurityNonRootUser' "$W/bsd/kern/bsd_init.c" | head -10 >> "$OUT"
say done

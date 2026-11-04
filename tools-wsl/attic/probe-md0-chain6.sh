#!/bin/bash
set -u
OUT=/mnt/e/Code/HackIos/out/probes/md0-chain6.txt
: > "$OUT"
say() { printf '%s\n' "$*" >> "$OUT"; }
W=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
T=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree

say "== 0. nm 工具确认 =="
ls /opt/unixnu-linux/llvm/bin/ 2>/dev/null | grep -i '^llvm-nm\|^nm' | head -5 >> "$OUT"
NM=$(ls /opt/unixnu-linux/llvm/bin/llvm-nm 2>/dev/null || echo nm)
say "NM=$NM"

say
say "== 1. memdev.o 实际符号（是否被 CONFIG_MEMDEV_INSECURE 掏空）=="
$NM -g "$T/build/xnu/ios-obj/DEVELOPMENT_ARM64_BCM2837/bsd/DEVELOPMENT/memdev.o" 2>&1 | head -25 >> "$OUT"
say "-- 大小对比：memdev.o vs 同目录 bdev 类 --"
ls -l "$T/build/xnu/ios-obj/DEVELOPMENT_ARM64_BCM2837/bsd/DEVELOPMENT/"{memdev.o,subr_devmap.o} 2>&1 >> "$OUT"

say
say "== 2. IOKitBSDInit.cpp 里 mdev* 的编译条件 =="
grep -n 'mdevlookup\|mdevgetrange\|CONFIG_MEMDEV\|MEMDEV' "$W/iokit/bsddev/IOKitBSDInit.cpp" >> "$OUT" 2>&1
say "-- 840..872 上下文（看外层 ifdef）--"
sed -n '836,872p' "$W/iokit/bsddev/IOKitBSDInit.cpp" >> "$OUT" 2>&1

say
say "== 3. memdev.o 的编译来源（哪个 Makefile 列了它）=="
grep -rn 'memdev' "$W/bsd/Makefile" "$W/bsd/dev/Makefile" 2>/dev/null | head -10 >> "$OUT"
say "-- 全树 Makefile 里 memdev --"
grep -rn 'memdev' "$W" --include='Makefile*' 2>/dev/null | head -10 >> "$OUT"

say
say "== 4. mdevinit 是否有真实调用者（除 config/MASTER）=="
grep -rn 'mdevinit' "$W/bsd" "$W/osfmk" "$W/iokit" "$W/libsa" 2>/dev/null | head -10 >> "$OUT"
say "-- configure()/autoconf 是否存在 --"
grep -rn 'void\s*configure\b' "$W/bsd/dev" 2>/dev/null | head -6 >> "$OUT"

say
say "== 5. RamBlock 组件是源码还是原版件 =="
sed -n '1,50p' /home/unixnu/code/umi-work-pin/tools/build_umi_data_display.py >> "$OUT" 2>&1
say "-- 其中 ram 组件相关行 --"
grep -n 'ram\|Ram\|RAM' /home/unixnu/code/umi-work-pin/tools/build_umi_data_display.py | head -25 >> "$OUT"

say
say "== 6. UniXNURamDiskDxe 暴露给内核的形式 =="
grep -n 'MemoryMap\|RAMDisk\|md0\|memdev\|Chosen\|memory-map' /home/unixnu/code/UniXNU-main/package/UniXNUPkg/Driver/UniXNURamDiskDxe/UniXNURamDiskDxe.c | head -25 >> "$OUT"
say done

#!/bin/bash
# J 步：真机屏证「MR <fs>= 一行都没有 + 尾部 error==0」——查 mockfs 到底在不在 vfsconf 链里
set -u
LOG=/mnt/e/Code/HackIos/out/probes/j-mountroot-loop.txt
: > "$LOG"
exec >>"$LOG" 2>&1

X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
K=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/kernel/entry-trace-kernel.macho
NM=/opt/unixnu-linux/llvm/bin/llvm-nm
VO="$X/bsd/vfs/vfs_subr.c"

echo "== 1. vfs_mountroot 函数体（for 循环到 return ENODEV）=="
S=$(grep -n '^vfs_mountroot' "$VO" | head -1 | cut -d: -f1)
E=$(grep -n 'return ENODEV' "$VO" | tail -1 | cut -d: -f1)
echo "func start=$S tail ENODEV=$E"
awk -v a="$S" -v b="$E" 'NR>=a && NR<=b {printf "%5d\t%s\n", NR, $0}' "$VO"
echo
echo "== 2. error 变量声明/初始化 =="
awk -v a="$S" -v b="$E" 'NR>=a && NR<=b && /int[ \t]+error|error[ \t]*=[ \t]*0/' "$VO"
echo
echo "== 3. 循环里跳过驱动的判据 =="
awk -v a="$S" -v b="$E" 'NR>=a && NR<=b && (/VFC_NOT_INUSE/ || /vfc_mountroot/ || /continue/ || /break/)' "$VO"
echo
echo "== 4. mockfs 是否编进这档内核 =="
echo "-- 4a. 符号 --"
"$NM" -C "$K" 2>/dev/null | grep -i mockfs | head -20
echo "mockfs 符号命中=$( "$NM" "$K" 2>/dev/null | grep -ci mockfs )"
echo "-- 4b. 字符串 --"
strings -a "$K" | grep -i mockfs | head -10
echo
echo "== 5. mockfs 的 vfsconf 条目怎么进链 =="
grep -rn 'mockfs' "$X/bsd/vfs/vfs_conf.c" "$X/bsd/miscfs/mockfs/"*.c 2>/dev/null | grep -Ei 'vfsconf|VFC|mountroot|list_add|TAILQ|osfmk' | head -20
echo
echo "== 6. 构建配置里 MOCKFS 开关 =="
grep -rn -i 'mockfs' "$X"/../*.cfg "$X"/../config* 2>/dev/null | head -10
grep -rn -i 'MOCKFS' /home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree --include='*.mk' --include='*.cfg' --include='Makefile*' 2>/dev/null | head -20
echo
echo "== 7. 已编出的 mockfs 目标文件 =="
find /home/unixnu/code/umi-work-pin/out/umi-xnu -name 'mockfs*.o' 2>/dev/null | head -10
echo "DONE"

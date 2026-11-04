#!/bin/bash
# J3：坐实「umi 手机档没开 MOCKFS」——读准 vfs_mountroot 循环 + 找 umi 构建的注入点 + 盘上哪档内核带 mockfs
set -u
LOG=/mnt/e/Code/HackIos/out/probes/j3-mockfs-inject.txt
: > "$LOG"
exec >>"$LOG" 2>&1

X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
VO="$X/bsd/vfs/vfs_subr.c"

echo "== 1. vfs_mountroot 精确函数体 =="
awk '/^vfs_mountroot\(/{f=1} f{printf "%5d\t%s\n", NR, $0} f&&/^\}/{exit}' "$VO" | head -230
echo
echo "== 2. umi 构建管线里有没有 SOURCE_MOCKFS 开关 =="
grep -rn -E 'SOURCE_MOCKFS|MOCKFS' /home/unixnu/code/UniXNU-umi/tools /home/unixnu/code/UniXNU-umi/devices /home/unixnu/code/UniXNU-umi/kits 2>/dev/null | head -30
echo
echo "== 3. umi 内核这一档是谁编的（找 build_umi_xnu.py 与它调用的编译脚本）=="
ls /home/unixnu/code/UniXNU-umi/tools/*.py 2>/dev/null | head -20
grep -rn -E 'build-xnu|prepare-xnu-source|make.*KERNEL|CFLAGS_ADD' /home/unixnu/code/UniXNU-umi/tools/build_umi_xnu.py 2>/dev/null | head -20
echo
echo "== 4. 盘上所有 kernel macho 的 mockfs 字符串命中 =="
for f in $(find /home/unixnu/code -name '*kernel*.macho' -size +1M 2>/dev/null | head -25); do
  printf '%s  mockfs=%s  size=%s\n' "$f" "$(strings -a "$f" | grep -c mockfs)" "$(stat -c %s "$f")"
done
echo
echo "== 5. umi 构建的 vfs_conf.o 与模式标记 =="
find /home/unixnu/code/umi-work-pin/out -name 'vfs_conf.o' 2>/dev/null | head -10
for o in $(find /home/unixnu/code/umi-work-pin/out -name 'vfs_conf.o' 2>/dev/null | head -10); do
  d=$(dirname "$o")
  printf '%s: mockfs_str=%s  mode_file=%s\n' "$o" "$(strings -a "$o" | grep -c mockfs)" "$(cat "$d/.source-mockfs-mode" 2>/dev/null || echo none)"
done
echo
echo "== 6. libmockfs_fixture.a 在不在 =="
find /home/unixnu/code/umi-work-pin/out -name 'libmockfs_fixture.a' 2>/dev/null | head -5
ls -la /home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/build/mockfs-fixture/ 2>/dev/null | head -12
echo
echo "== 7. umi 链接命令里有没有 force_load mockfs =="
grep -rn -E 'force_load' /home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/scripts/build-xnu-4k-baseline.sh 2>/dev/null | head -20
find /home/unixnu/code/umi-work-pin/out/umi-xnu -name '*.sh' -newermt '2026-11-01' 2>/dev/null | head -20
echo "DONE"

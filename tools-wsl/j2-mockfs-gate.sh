#!/bin/bash
# J2：mockfs 为什么没进真机内核——找 vfs_conf.c 的编译闸 + 对比 QEMU 那档内核
set -u
LOG=/mnt/e/Code/HackIos/out/probes/j2-mockfs-gate.txt
: > "$LOG"
exec >>"$LOG" 2>&1

X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
KDIR=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/kernel
NM=/opt/unixnu-linux/llvm/bin/llvm-nm
VO="$X/bsd/vfs/vfs_conf.c"

echo "== 1. vfs_conf.c mockfs 条目上下文（含 #if 闸）=="
awk 'NR>=180 && NR<=232 {printf "%5d\t%s\n", NR, $0}' "$VO"
echo
echo "== 2. 该闸用的宏名在树里怎么定义 =="
for m in CONFIG_MOCKFS SOURCE_MOCKFS MOCKFS; do
  echo "-- $m --"
  grep -rn "$m" "$X" --include='*.c' --include='*.h' 2>/dev/null | grep -vE 'miscfs/mockfs/' | head -8
done
echo
echo "== 3. 构建侧配置里搜（不限 .c/.h）=="
grep -rn -E 'MOCKFS' /home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree --include='*.mk' --include='*.cfg' --include='Makefile*' --include='*.py' --include='*.sh' --include='*.xcs' --include='*.plist' 2>/dev/null | head -25
echo
echo "== 4. 生成的 config 头里有没有 MOCKFS =="
find /home/unixnu/code/umi-work-pin/out/umi-xnu -name '*.h' -path '*config*' 2>/dev/null | head -10
for f in $(find /home/unixnu/code/umi-work-pin/out/umi-xnu -name 'config.h' -o -name '*options*.h' 2>/dev/null | head -8); do
  printf '%s: MOCKFS=%s\n' "$f" "$(grep -ci mockfs "$f")"
done
echo
echo "== 5. kernel 目录里都有哪几档内核，各自 mockfs 符号数 =="
ls -la "$KDIR" 2>/dev/null | head -20
for k in "$KDIR"/*.macho; do
  [ -f "$k" ] || continue
  printf '%s  size=%s  mockfs=%s  vfs_mountroot=%s  hfs=%s apfs=%s\n' \
    "$(basename "$k")" "$(stat -c %s "$k")" \
    "$("$NM" "$k" 2>/dev/null | grep -ci mockfs)" \
    "$("$NM" "$k" 2>/dev/null | grep -c 'vfs_mountroot')" \
    "$("$NM" "$k" 2>/dev/null | grep -ci hfs)" \
    "$("$NM" "$k" 2>/dev/null | grep -ci apfs)"
done
echo
echo "== 6. 真机这档内核里 vfsconf 到底有哪些名字 =="
K=$(ls -t "$KDIR"/entry-trace-kernel.macho 2>/dev/null)
strings -a "$K" | grep -xE 'apfs|hfs|msdos|cd9660|devfs|procfs|tmpfs|mockfs|smbfs|nfsv[0-9]|autofs|fusefs|ntfs|tarfs|rootfs|efivarfs' | sort -u
echo
echo "== 7. QEMU 用的内核路径（从 run 记录里找）=="
grep -rn -m3 -iE 'kernel.*macho|kernel=' /mnt/e/Code/HackIos/tools/run_umi_qemu.py 2>/dev/null | head -10
ls -t /mnt/e/Code/HackIos/out/qemu 2>/dev/null | head -8
echo "DONE"

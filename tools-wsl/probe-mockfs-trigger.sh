#!/bin/bash
set -u
OUT=/mnt/e/Code/HackIos/out/mockfs-trigger.txt
: > "$OUT"
say() { printf '%s\n' "$*" >> "$OUT"; }
X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
W=/home/unixnu/code/umi-work-pin
U=/home/unixnu/code/UniXNU-umi

say "== 1. vfs_conf.c 的 MOCKFS 块（触发条件）=="
grep -n 'MOCKFS' "$X/bsd/kern/vfs_conf.c" | head -10 >> "$OUT"
L=$(grep -n 'if (MOCKFS' "$X/bsd/kern/vfs_conf.c" | head -1 | cut -d: -f1)
say "L=$L"
test -n "$L" && sed -n "$((L-14)),$((L+26))p" "$X/bsd/kern/vfs_conf.c" >> "$OUT"

say
say "== 2. mockfs_vfsops.c 的挂载与根节点 =="
grep -n 'vfs_mount\|mockfs_vfsroot\|P_mountroot\|rootvpp\|fsmount\|statfs\|MBFS\|mountflag' "$X/bsd/miscfs/mockfs/mockfs_vfsops.c" | head -25 >> "$OUT"
say "-- 头 40 行 --"
sed -n '1,40p' "$X/bsd/miscfs/mockfs/mockfs_vfsops.c" >> "$OUT" 2>&1

say
say "== 3. mockfs 根目录里有什么（能否 exec init）=="
grep -n 'exec\|VNOP\|lookup\|vnode\|devvp\|mknodes\|ino' "$X/bsd/miscfs/mockfs/mockfs_vnops.c" | head -20 >> "$OUT"
grep -n 'mockfs_node\|name\|size' "$X/bsd/miscfs/mockfs/mockfs_fsnode.c" | head -25 >> "$OUT"

say
say "== 4. 两份 build_umi_xnu.py 是不是同一文件 =="
for f in "$W/tools/build_umi_xnu.py" "$U/tools/build_umi_xnu.py" "$U/bringup/tools/build_umi_xnu.py"; do
  say "$f -> $(test -e "$f" && sha256sum "$f" | cut -c1-16 || echo MISSING) inode=$(stat -c %i "$f" 2>/dev/null)"
done
say done

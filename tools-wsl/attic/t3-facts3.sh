#!/bin/bash
# T 步事实核对（三）：mockfs 名字解析（lookup 把哪个名字给哪个节点）+ 现成 trust bundle
set -u
exec > /mnt/e/Code/HackIos/out/probes/t3-facts3.txt 2>&1
X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
U=/home/unixnu/code/UniXNU-main

echo "== 1. mockfs_vnops.c 的 lookup：名字 → 节点 =="
grep -n -B6 -A40 'mockfs_lookup' "$X/bsd/miscfs/mockfs/mockfs_vnops.c" | head -120

echo
echo "== 2. mockfs.h 里有没有文件名常量 =="
grep -n 'launchd\|dyld\|name\|"dev"\|MOCKFS' "$X/bsd/miscfs/mockfs/mockfs.h" | head -40

echo
echo "== 3. 有没有已经存在的、sha 命中 7416ca4f… 的 trust bundle =="
python3 - <<'PY'
import hashlib, pathlib
target = '7416ca4f8377146626bb284e2133c76bee6cb4e3ee0af5d648b186235a7323a7'
roots = ['/home/unixnu/code/UniXNU-main', '/home/unixnu/code/umi-work-pin']
seen = 0
for r in roots:
    for p in pathlib.Path(r).rglob('*'):
        if not p.is_file() or p.stat().st_size < 24:
            continue
        n = p.name.lower()
        if 'trust' not in n and 'bundle' not in n and not n.endswith('.ctbt'):
            continue
        seen += 1
        h = hashlib.sha256(p.read_bytes()).hexdigest()
        print(('HIT ' if h == target else '    ') + h[:16] + '  ' + str(p) + f'  {p.stat().st_size:,} B')
        if seen > 60:
            raise SystemExit('too many, stop')
print('scanned', seen)
PY

echo
echo "== 4. make-owner-trust-bundle.py 全文（能不能纯 Linux 造 bundle）=="
cat -n "$U/scripts/make-owner-trust-bundle.py" 2>/dev/null | head -80

echo
echo "== 5. 上游 fixture 归档里有没有现成 root.img/bundle =="
ls -l "$U/build/" 2>/dev/null | grep -i 'dyld-fixture\|trust\|cache-file' | head -20
for d in target-dyld-fixture native-cache-file-fixture; do
  echo "-- $U/build/$d --"; ls -l "$U/build/$d" 2>/dev/null
done
echo "== done $(date -u +%FT%TZ)"

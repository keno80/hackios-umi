#!/bin/bash
# K3：取最后两个锚点（sleh.c 的 SVC 分派 + init_programs 数组内容），并确认 mockfs 容器里的 launchd 路径
set -u
LOG=/mnt/e/Code/HackIos/out/probes/k3-el0-anchor2.txt
: > "$LOG"
exec >>"$LOG" 2>&1
X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work

echo "== 1. sleh.c 1900..1965（SVC → mach/unix 分派）=="
awk 'NR>=1900 && NR<=1965 {printf "%5d\t%s\n", NR, $0}' "$X/osfmk/arm64/sleh.c"
echo
echo "== 2. init_programs 数组 =="
grep -n 'init_programs' "$X/bsd/kern/kern_exec.c" | head
S=$(grep -n 'init_programs\[\] *=' "$X/bsd/kern/kern_exec.c" | head -1 | cut -d: -f1)
echo "start=$S"
[ -n "$S" ] && awk -v a=$((S-6)) -v b=$((S+16)) 'NR>=a && NR<=b {printf "%5d\t%s\n", NR, $0}' "$X/bsd/kern/kern_exec.c"
echo
echo "== 3. mockfs 容器里 launchd 的路径（fixture 生成侧）=="
grep -rn 'sbin/launchd\|MOCKFS_FILE\|mockfs_file' /home/unixnu/code/UniXNU-main/scripts/build-native-user-fixture.py 2>/dev/null | head -12
echo
echo "== 4. 假根卷里实际有哪些路径（读 N4KROOT 头）=="
python3 - <<'PY'
import struct
p='/home/unixnu/code/UniXNU-main/build/native-user-fixture-umi/launchd.macho'
d=open(p,'rb').read()
magic=d[:8]; ver,count=struct.unpack_from('<2I',d,8)
lo,ls,to,ts=struct.unpack_from('<4Q',d,16)
print('magic',magic,'ver',ver,'count',count,'launch',hex(lo),ls,'test',hex(to),ts,'total',len(d))
tail=d[to:to+ts]
import re
for m in re.finditer(rb'/[A-Za-z0-9_./-]{3,64}', tail[:4096]):
    print('  path', m.group().decode())
PY
echo
echo "== 5. sleh.c 顶部 include（打点要的头）=="
grep -n '#include' "$X/osfmk/arm64/sleh.c" | head -30
echo "DONE"

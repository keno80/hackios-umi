#!/bin/bash
# 屏上 -19/-18 都回 0x11(17)。这里把 17 钉到名字，并顺着 mod_refs 的内核路径找哪条分支发它。
set -u
exec > /mnt/e/Code/HackIos/out/probes/r28c-code17.txt 2>&1
X=/home/unixnu/code/UniXNU-main/out/feeds/xnu-0b4b910d

echo "== 1. kern_return 枚举头在哪 =="
find "$X/osfmk/mach" -maxdepth 1 -name 'kern_return*' -o -maxdepth 1 -name 'return_code*' 2>/dev/null
ls "$X/osfmk/mach/" | grep -i 'kern_return\|return' || true

echo
echo "== 2. 17 是谁（打印 0..25 的枚举）=="
H=$(find "$X/osfmk/mach" -name 'kern_return.h' | head -1)
echo "H=$H"
grep -nE 'KERN_[A-Z_]+ +=+ *[0-9]+' "$H" | head -40

echo
echo "== 3. mod_refs trap 的实现 =="
grep -rn -A25 '_kernelrpc_mach_port_mod_refs_trap' "$X/osfmk/ipc/ipc_mach.c" | head -50

echo
echo "== 4. ipc_right_delta 里发 KERN_INVALID_CAPABILITY / INVALID_RIGHT 的行 =="
grep -n 'KERN_INVALID_CAPABILITY\|KERN_INVALID_RIGHT\|ipc_right_delta' "$X/osfmk/ipc/ipc_right.c" | head -30

echo
echo "== 5. 本树 secure ports / capability 编码开关 =="
grep -rn 'MACH_PORT_CAP_BITS\|SECURE_TASKS\|ipc_port_fastlinks\|capability' "$X/osfmk/mach/port.h" | head -20

echo
echo "== 6. 件里 allocate 回来的 name 是多少（读 _pname 槽）=="
echo "gdb-stop 里 x26=0x100004520 即 &_pname；见 run-31-mach-gdb-stop.json 的 user-memory 段"
python3 - <<'PY'
import json
p="/mnt/e/Code/HackIos/out/probes/run-31-mach-gdb-stop.json"
d=json.load(open(p))
for k,v in d.items():
    if 'user' in k or 'memory' in k or 'read' in k:
        print(k, type(v).__name__)
PY
echo "== done $(date -u +%FT%TZ)"

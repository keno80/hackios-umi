#!/bin/bash
# S 步判读取证：屏上 svc=-21 r0=0xf 这个返回码在本树里叫什么。
# 为什么不能凭记忆：本树 kern_return 编号和 Darwin 习惯不一样（已实测 17=KERN_INVALID_RIGHT，
# 而 Darwin 里 17 是 KERN_INVALID_CAPABILITY），所以必须从本树的头文件把 0..25 整段抠出来对照。
# 顺带把 s13 没落盘的原因查清楚（重跑一遍 legacy mach_msg 取证）。
set -u
exec > /mnt/e/Code/HackIos/out/probes/s14-decode-0xf.txt 2>&1
X=/home/unixnu/code/UniXNU-main/out/feeds/xnu-0b4b910d

echo "== 0. 源码根是否存在 =="
ls -d "$X" 2>&1
ls "$X/osfmk/mach/kern_return.h" 2>&1

echo
echo "== 1. 本树 kern_return 全枚举（0..30）=="
grep -n 'define KERN_' "$X/osfmk/mach/kern_return.h" | head -80

echo
echo "== 2. 只挑 0xf=15 与 0x11=17 两行 =="
grep -nE 'define KERN_[A-Z_]+ +(15|17)$' "$X/osfmk/mach/kern_return.h"

echo
echo "== 3. _kernelrpc_mach_port_insert_right_trap 的实现与它的返回码来源 =="
grep -rn 'kernelrpc_mach_port_insert_right_trap' "$X/osfmk/ipc/ipc_mqueue.c" "$X/osfmk/ipc/mach_ipc.c" \
  "$X/osfmk/ipc/ipc_right.c" 2>/dev/null | head
grep -n -A45 'ipc_right_insert_port' "$X/osfmk/ipc/ipc_right.c" 2>/dev/null | grep -nE 'KERN_|iret|return' | head -40

echo
echo "== 4. ipc_right_insert 里能返回 15 的那条（UREFS_OVERFLOW 之类）=="
grep -n 'KERN_UREFS_OVERFLOW\|KERN_RIGHT_EXISTS\|KERN_INVALID_RIGHT\|KERN_FAILURE' \
  "$X/osfmk/ipc/ipc_right.c" | head -30

echo
echo "== 5. poly=0 + MAKE_SEND 的语义：insert_right 需要什么权利 =="
grep -n -B3 -A22 'ipc_mqueue_send_right\|poly == MACH_PORT_POLY_FAKE\|insert right.*MACH_PORT_RIGHT_SEND' \
  "$X/osfmk/ipc/ipc_right.c" 2>/dev/null | head -40

echo
echo "== 6. 现场 JSON 里的 _walk/_nz 原值 =="
J=/mnt/e/Code/HackIos/out/probes/run-32-vm-gdb-stop.json
if [ -f "$J" ]; then
  python3 - "$J" <<'PY'
import json,sys
d=json.load(open(sys.argv[1]))
def hexdump(name, off):
    v=d.get(name)
    print(f"-- {name} @0x{off:x}: type={type(v).__name__}")
    print(repr(v)[:2000])
for k in d:
    print("KEY", k)
PY
else
  echo "no json at $J"
fi
echo "== done =="

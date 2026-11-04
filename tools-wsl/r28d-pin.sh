#!/bin/bash
# 坐实两件事：17 的名字，以及「allocate 出来的 receive right 是 pinned」这条为什么会挡住 mod_refs/deallocate。
set -u
exec > /mnt/e/Code/HackIos/out/probes/r28d-pin.txt 2>&1
X=/home/unixnu/code/UniXNU-main/out/feeds/xnu-0b4b910d

echo "== 1. 17 的名字 =="
grep -n 'KERN_[A-Z_]*' "$X/osfmk/mach/kern_return.h" | grep -E '= *[0-9]+' | head -40

echo
echo "== 2. pinned 判据（ipc_right.c 901/962 上下文）=="
sed -n '895,1000p' "$X/osfmk/ipc/ipc_right.c"

echo
echo "== 3. allocate 是否默认 pin receive right =="
grep -n 'ip_receive_rights_pinned\|MPC_RECEIVE_RIGHTS_PINNED\|ipc_port_set_pinned\|pin' \
  "$X/osfmk/ipc/ipc_port.c" | head -25
echo "--- ipc_port_alloc_name 尾部："
grep -n -A40 'ipc_port_alloc_name(' "$X/osfmk/ipc/ipc_port.c" | sed -n '1,60p'

echo
echo "== 4. deallocate 分支（1178 上下文）=="
sed -n '1160,1190p' "$X/osfmk/ipc/ipc_right.c"
echo "== done $(date -u +%FT%TZ)"

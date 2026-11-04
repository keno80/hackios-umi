#!/bin/bash
# R 步判读补证：屏上 -19/-18 两发回 r0=0x11(17)，把它钉到具体 kern_return_t 名字上，
# 顺带核对 port_allocate 的 right 参数在内核里怎么解释（我件里传的是 1）。
set -u
exec > /mnt/e/Code/HackIos/out/probes/r28-return-code.txt 2>&1
T=/home/unixnu/code/UniXNU-main/out/feeds/xnu-0b4b910d
K=$T/osfmk/mach/return_codes.h
R=$T/osfmk/mach/port.h
P=$T/osfmk/ipc/ipc_port.c

echo "== 0. 文件在不在 =="
ls -la "$K" "$R" "$P" 2>&1

echo
echo "== 1. kern_return_t 里 17 是谁（按枚举顺序数）=="
grep -nE 'KERN_[A-Z_]+ +=+ *1?[0-9]{1,2}' "$K" 2>/dev/null | head -60
echo "--- 直接找 17："
grep -n ' 17\b\|=17\b\|= 17' "$K" | head -10

echo
echo "== 2. MACH_PORT_RIGHT_* 的用户态值 =="
grep -n 'MACH_PORT_RIGHT_SEND\b\|MACH_PORT_RIGHT_RECEIVE\b\|MACH_PORT_RIGHT_SEND_ONCE\b' "$R" | head -20
echo "--- MAKEIND 定义："
grep -n -A3 'define MACH_PORT_RIGHT_MAKEIND' "$R" | head -10

echo
echo "== 3. port_allocate 内核侧怎么用 right =="
grep -n -A22 '_kernelrpc_mach_port_allocate_trap' "$T/osfmk/ipc/ipc_mach.c" 2>/dev/null | head -40

echo
echo "== 4. mod_refs 里能返回 17 的那条路 =="
grep -rn 'KERN_INVALID_CAPABILITY' "$T/osfmk/ipc/"*.c | head -20

echo
echo "== 5. 件里 -19/-18 实参（从 walk-user.S 直接看）=="
grep -n -B2 -A12 'mach_port_mod_refs\|mach_port_deallocate\|mach_port_allocate' \
  /mnt/e/Code/HackIos/tools-wsl/umi-fixture/walk-user.S | head -80
echo "== done $(date -u +%FT%TZ)"

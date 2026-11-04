#!/bin/bash
# R 步之五：下一批 EL0 走查要打的 Mach trap 号，从树里取，不凭记忆。
# 与 unix syscall 同理：号表必须是内核构建实际生成的那份（mach.trap.h / mach_syscalls），
# 凭记忆写错 = 打一发不存在的 trap，轻则 KERN_FAILURE 重则踩分派表越界。
set -u
LOG=/mnt/e/Code/HackIos/out/probes/r11-mach-traps.txt
: > "$LOG"
exec >> "$LOG" 2>&1

W=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi
X=$W/tree/.cache/xnu-work
H=$W/tree/build/xnu/ios-obj/EXPORT_HDRS/mach/mach.trap.h
echo "== 0. 候选号表文件 =="
ls -la "$H" 2>/dev/null || echo "没有 $H"
find "$W/tree/build" -name 'mach.trap.h' -o -name 'mach_syscalls.h' 2>/dev/null | head -5
echo
if [ -f "$H" ]; then
  echo "== 1. 头里的 trap 号 =="
  for n in MACH_MSG MACH_MSG_OVERWRITE MACH_REPLY MACH_DESTROY MACH_DEALLOCATE_MACH \
           MACH_PORT_DEALLOCATE MACH_PORT_INSERT MACH_PORT_EXTRACT MACH_PORT_MOD_REFS \
           MACH_PORT_GET_RIGHTS MACH_PORT_SET_LIMITS MACH_TASK_SELF MACH_HOST_SELF \
           MACH_TASK_GET_SPECIAL_PORT MACH_VM_ALLOCATE MACH_VM_DEALLOCATE MACH_VM_MAP \
           MACH_TIMEInsensitive_HOST_INFO HOST_INFO THREAD_SELF MACH_PORT_ALLOCATE \
           SEMAPHORE_SIGNAL MACH_NOTIFY_PORT_DEATH; do
    v=$(grep -E "^[[:space:]]*#[[:space:]]*define[[:space:]]+${n}[[:space:]]+[0-9]+" "$H" | awk '{print $3}' | head -1)
    printf '%-32s %s\n' "$n" "${v:-NONE}"
  done
  echo
  echo "== 2. 头里前 40 行（看清编号从几开始）=="
  head -40 "$H"
fi
echo
echo "== 3. 分派表与 trap 上限（越界就是踩表）=="
grep -rn "MAXMACHTRAPS\|mach_trap_table\[\]" "$X/osfmk/kern/syscall_sw.c" 2>/dev/null | head -6
echo
echo "== 4. sleh.c 里 mach trap 的分派（我们的 22z 探针挂在哪儿）=="
grep -n "MACHDEP_SYSCALL_BASE\|ESR_EC_SVC_64\|trap_no\|EL0 MACH" "$X/osfmk/arm64/sleh.c" | head -16
echo "== done $(date -u +%FT%TZ)"

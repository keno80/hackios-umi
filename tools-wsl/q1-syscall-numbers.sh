#!/bin/bash
# Q 步之一：下一批 EL0 走查要用的 unix syscall 号，从树里取而不是凭记忆猜。
# 凭记忆写错号 = 打了一发不存在的 svc，轻则 ENOSYS 重则踩分派表，上机一次全白。
#
# 号表来源必须是**内核构建实际生成的那份** bsd/sys/syscall.h（EXPORT_HDRS）：
# syscalls.master 的列是 `编号 AUDIT Files name(args)`，名字和括号之间没有空格，
# 拿 awk 按空白切字段去比 name 会大面积 NONE（第一版就这么被骗过一轮）。
set -u
LOG=/mnt/e/Code/HackIos/out/probes/q1-syscall-numbers.txt
: > "$LOG"
exec >>"$LOG" 2>&1

W=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi
H=$(ls "$W"/tree/build/xnu/*/EXPORT_HDRS/bsd/sys/syscall.h 2>/dev/null | head -1)
[ -f "$H" ] || { echo "== 拒绝判读：找不到生成的 syscall.h（内核没编过？）"; exit 1; }
echo "== 号表 = $H"
ls -la "$H" | sed 's#^# #'
echo

echo "== 候选号 =="
for n in exit fork read write open close wait4 getpid getppid umask chdir fchdir dup dup2 fcntl \
         select poll madvise mincore msync munmap mprotect mmap pipe issetugid stat64 sysctl \
         sigaction sigprocmask kill setitimer fstat flock ioctl rename unlink link mkdir rmdir \
         posix_spawn execve kqueue kevent shm_open sem_open; do
  v=$(grep -E "^[[:space:]]*#[[:space:]]*define[[:space:]]+SYS_${n}[[:space:]]+[0-9]+" "$H" | awk '{print $3}' | head -1)
  printf '%-24s %s\n' "$n" "${v:-NONE}"
done
echo

echo "== 两词返回值的 ABI（pipe 这类）：内核把 rval[0]→x0、rval[1]→x1 =="
grep -n "uu_rval\[0\]\|uu_rval\[1\]" "$W/tree/.cache/xnu-work/bsd/dev/arm/systemcalls.c" | head -6
echo "-- master 里 pipe 的原文（没有内存出参）--"
grep -nE "^42[[:space:]]" "$W/tree/.cache/xnu-work/bsd/kern/syscalls.master"
echo "== done $(date -u +%FT%TZ)"

#!/bin/bash
# 落成 umi-fork-child-zero 补丁（26z）：fork() 唤醒子线程之前，把子进程的 x0 强制成 0。
# 依据（run-25 实测 + 上游逐字对照）：
#   fork1() 里 thread_set_child(child_thread, proc_getpid(child_proc)) 把「子进程自己的 pid」
#   写进子线程的用户保存帧；thread_bootstrap_return → arm64_thread_exception_return →
#   exception_return 正是从那一帧恢复 x0，于是子进程带回 EL0 的 fork 返回值是 pid 而非 0，
#   走查件的 cbz x0,_child 不跳，父子都去 wait4，没人 exit，父进程永久睡等。
#   上游 xnu-12377.121.6 的 thread_set_child 与此完全一致，所以不是本仓改坏，是这条通路
#   在 stock 路径上依赖别的东西归零（本环境没有），先按 POSIX 契约显式补 0。
set -uo pipefail
OUT=/mnt/e/Code/HackIos/out/probes/n-make-fork-child-zero-patch.txt
: > "$OUT"
exec >>"$OUT" 2>&1

WS=/home/unixnu/code/umi-work-pin
X=$WS/out/umi-xnu/umi/tree/.cache/xnu-work
DEV=/home/unixnu/code/UniXNU-umi
ARCH=/mnt/e/Code/HackIos/patches/umi-xnu
NAME=zzzzzzzzzzzzzzzzzzzzzzzzzz-umi-fork-child-zero.patch

echo "== 0. 基线必须已含 25z（本补丁的锚点是打过 25z 的文本）=="
C=$(grep -c 'FORK child-woken' "$X/bsd/kern/kern_fork.c")
echo "25z 标记计数=$C"
if [ "$C" = "0" ]; then
  echo "== 0a. 基线没 25z，先正向打上 =="
  ( cd "$X" && patch -p1 < "$DEV/patches/umi-xnu/zzzzzzzzzzzzzzzzzzzzzzzzz-umi-fork-probe.patch" ) \
    && echo "PRE-APPLY-OK" || { echo "PRE-APPLY-FAIL"; exit 1; }
  grep -c 'FORK child-woken' "$X/bsd/kern/kern_fork.c"
fi
grep -n 'thread_set_child' "$X/bsd/kern/kern_fork.c"

echo
echo "== 1. 生成 =="
WORK=$(mktemp -d)
mkdir -p "$WORK/a/bsd/kern" "$WORK/b/bsd/kern"
cp "$X/bsd/kern/kern_fork.c" "$WORK/a/bsd/kern/"
cp "$X/bsd/kern/kern_fork.c" "$WORK/b/bsd/kern/"

python3 - "$WORK" <<'PY'
import pathlib, sys

work = pathlib.Path(sys.argv[1])
rel = "bsd/kern/kern_fork.c"
old = ("\t\t/* \"Return\" to the child */\n"
       "\t\ttask_clear_return_wait(get_threadtask(child_thread), TCRW_CLEAR_ALL_WAIT);\n")
new = ("\t\t/* \"Return\" to the child */\n"
       "\t\t/*\n"
       "\t\t * UMI bring-up: fork1() left this thread's user frame x0 set to the\n"
       "\t\t * child's own pid (thread_set_child(child_thread, proc_getpid(...))),\n"
       "\t\t * and thread_bootstrap_return restores x0 straight out of that frame,\n"
       "\t\t * so the child came back to EL0 with a non-zero fork() result and took\n"
       "\t\t * the parent's branch. POSIX wants 0 here.\n"
       "\t\t */\n"
       "\t\tthread_set_child(child_thread, 0);\n"
       "\t\tboot_progress_stage(\"FORK cx0=0\");\n"
       "\t\ttask_clear_return_wait(get_threadtask(child_thread), TCRW_CLEAR_ALL_WAIT);\n")

p = work / "b" / rel
text = p.read_text()
n = text.count(old)
assert n == 1, ("anchor-count", n)
p.write_text(text.replace(old, new))
print("edited", rel)
PY
[ $? -eq 0 ] || { echo "EDIT-FAIL"; rm -rf "$WORK"; exit 1; }

echo
echo "== 2. diff =="
{
  echo "--- a/bsd/kern/kern_fork.c"
  echo "+++ b/bsd/kern/kern_fork.c"
  ( cd "$WORK" && diff -u "a/bsd/kern/kern_fork.c" "b/bsd/kern/kern_fork.c" ) | tail -n +3
} | tee "$WORK/body.diff"

echo
echo "== 3. 落盘 =="
cp "$WORK/body.diff" "$DEV/patches/umi-xnu/$NAME"
cp "$WORK/body.diff" "$ARCH/$NAME"
ls -la "$DEV/patches/umi-xnu/$NAME" "$ARCH/$NAME"
sha256sum "$DEV/patches/umi-xnu/$NAME" "$ARCH/$NAME"

echo
echo "== 4. 真实打回基线并核串 =="
( cd "$X" && patch -p1 < "$DEV/patches/umi-xnu/$NAME" ) && echo "APPLY-OK" || echo "APPLY-FAIL"
grep -n 'thread_set_child(child_thread, 0)\|FORK cx0=0' "$X/bsd/kern/kern_fork.c"

echo
echo "== 5. CRLF 检查 =="
for f in "$DEV/patches/umi-xnu/$NAME" "$ARCH/$NAME"; do
  printf '%s CR=%s\n' "$f" "$(tr -dc '\r' < "$f" | wc -c)"
done

echo
echo "== 6. 重放顺序（26z 必须紧跟 25z）=="
ls "$DEV/patches/umi-xnu/" | grep '^z' | sort | tail -3
rm -rf "$WORK"
echo done

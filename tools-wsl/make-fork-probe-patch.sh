#!/bin/bash
# 落成 umi-fork-probe 补丁（25z）：把 fork 子任务「有 pid、没进 EL0、wait4 时已被收干」这段
# 从看不见的内核分支搬到画屏通道。
#   判据来自 kern_fork.c:621 —— if (parent_proc->p_lflag & P_LEXIT || !thread_is_active(current_thread()))
#   会 task_terminate_internal(child_task) 并让 reap_child_locked 内部收尸；
#   全树 thread->active 只有 thread_create_internal() 一处置 TRUE，所以 init 那条线程的
#   active 位是真是假，只能上机/上 QEMU 直接读。
# 基线取构建真正消费的 .cache/xnu-work（已含 17z…24z），产物同时落 ext4 设备仓与 Windows 归档。
# v2：run-24 红底 panic 坐实第一版把探针插在了 ECHILD 分支的 p 上，而那里的 p 是耗尽的子进程
#     游标（NULL），pc 解到 _wait4_nocancel+0x1e0、far=0x60。改用等待方 q，并判空。
# 本脚本可重复跑：基线若已含本补丁会先反向剥掉，出片后再正向打回。
set -uo pipefail
OUT=/mnt/e/Code/HackIos/out/probes/n-make-fork-probe-patch.txt
: > "$OUT"
exec >>"$OUT" 2>&1

WS=/home/unixnu/code/umi-work-pin
X=$WS/out/umi-xnu/umi/tree/.cache/xnu-work
DEV=/home/unixnu/code/UniXNU-umi
ARCH=/mnt/e/Code/HackIos/patches/umi-xnu
NAME=zzzzzzzzzzzzzzzzzzzzzzzzz-umi-fork-probe.patch

echo "== 0. 基线在不在 + 有没有别的补丁也改这两个文件 =="
for REL in bsd/kern/kern_fork.c bsd/kern/kern_exit.c; do
  ls -la "$X/$REL" || { echo "NO-BASELINE $REL"; exit 1; }
done
echo "-- 既有补丁命中（非空说明锚点要比的是打过补丁后的文本）--"
grep -l 'bsd/kern/kern_fork.c\|bsd/kern/kern_exit.c' "$ARCH"/*.patch || echo "（无）"
echo "-- kern_fork.c 里 snprintf 可用性线索 --"
grep -n '#include <sys/systm.h>\|#include <mach/thread_act.h>' "$X/bsd/kern/kern_fork.c" | head -4

echo
echo "== 0a. 若基线已含本补丁（上一轮构建留下的），先反向剥掉回到 24z 态 =="
if grep -q 'FORK cpid=' "$X/bsd/kern/kern_fork.c"; then
  ( cd "$X" && patch -R -p1 < "$DEV/patches/umi-xnu/$NAME" ) && echo "REVERSED-OK" || { echo "REVERSE-FAIL"; exit 1; }
else
  echo "（基线干净，无需剥）"
fi
grep -c 'FORK cpid=\|WAIT4 A none\|REAP cpid=' "$X/bsd/kern/kern_fork.c" "$X/bsd/kern/kern_exit.c"

echo
echo "== 1. 生成 =="
WORK=$(mktemp -d)
mkdir -p "$WORK/a/bsd/kern" "$WORK/b/bsd/kern"
cp "$X/bsd/kern/kern_fork.c" "$WORK/a/bsd/kern/"
cp "$X/bsd/kern/kern_fork.c" "$WORK/b/bsd/kern/"
cp "$X/bsd/kern/kern_exit.c" "$WORK/a/bsd/kern/"
cp "$X/bsd/kern/kern_exit.c" "$WORK/b/bsd/kern/"

python3 - "$WORK" <<'PY'
import pathlib, sys

work = pathlib.Path(sys.argv[1])

edits = {
    "bsd/kern/kern_fork.c": [
        (
            "#include <mach/thread_act.h>    /* for thread_resume() */\n",
            "#include <mach/thread_act.h>    /* for thread_resume() */\n"
            "#include <kern/boot_progress.h> /* UMI bring-up: boot_progress_stage reaches the painter */\n",
        ),
        (
            "\t\t/* Return to the parent */\n"
            "\t\tchild_proc = (proc_t)get_bsdthreadtask_info(child_thread);\n"
            "\t\tretval[0] = proc_getpid(child_proc);\n",
            "\t\t/* Return to the parent */\n"
            "\t\tchild_proc = (proc_t)get_bsdthreadtask_info(child_thread);\n"
            "\t\tretval[0] = proc_getpid(child_proc);\n"
            "\t\t/*\n"
            "\t\t * UMI bring-up: the reaper below keys on thread_is_active(current_thread()),\n"
            "\t\t * and thread->active is only ever set TRUE by thread_create_internal().\n"
            "\t\t * Whether the init thread carries that bit is a runtime fact, so put it on\n"
            "\t\t * the screen instead of guessing.\n"
            "\t\t */\n"
            "\t\t{\n"
            "\t\t\tchar umi_msg[96];\n"
            "\n"
            "\t\t\t(void)snprintf(umi_msg, sizeof(umi_msg),\n"
            "\t\t\t    \"FORK cpid=%d act=%d lex=%d\", (int)retval[0],\n"
            "\t\t\t    (int)thread_is_active(current_thread()),\n"
            "\t\t\t    (parent_proc->p_lflag & P_LEXIT) != 0);\n"
            "\t\t\tboot_progress_stage(umi_msg);\n"
            "\t\t}\n",
        ),
        (
            "\t\tif (parent_proc->p_lflag & P_LEXIT || !thread_is_active(current_thread())) {\n"
            "\t\t\ttask_terminate_internal(child_task);\n",
            "\t\tif (parent_proc->p_lflag & P_LEXIT || !thread_is_active(current_thread())) {\n"
            "\t\t\tboot_progress_stage(\"FORK deadparent-reap\");\n"
            "\t\t\ttask_terminate_internal(child_task);\n",
        ),
        (
            "\t\t/* \"Return\" to the child */\n"
            "\t\ttask_clear_return_wait(get_threadtask(child_thread), TCRW_CLEAR_ALL_WAIT);\n",
            "\t\t/* \"Return\" to the child */\n"
            "\t\ttask_clear_return_wait(get_threadtask(child_thread), TCRW_CLEAR_ALL_WAIT);\n"
            "\t\tboot_progress_stage(\"FORK child-woken\");\n",
        ),
    ],
    "bsd/kern/kern_exit.c": [
        (
            "\t/* list lock is held when we get here any which way */\n"
            "\tif (nfound == 0) {\n"
            "\t\tproc_list_unlock();\n"
            "\t\treturn ECHILD;\n",
            "\t/* list lock is held when we get here any which way */\n"
            "\tif (nfound == 0) {\n"
            "\t\tchar umi_msg[96];\n"
            "\n"
            "\t\t/* p is the exhausted child cursor here (run-24 panicked on it at\n"
            "\t\t * _wait4_nocancel+0x1e0, far=0x60); q is the waiting parent. */\n"
            "\t\t(void)snprintf(umi_msg, sizeof(umi_msg),\n"
            "\t\t    \"WAIT4 A none pid=%d cnt=%d\",\n"
            "\t\t    (q != NULL) ? (int)q->p_pid : -1,\n"
            "\t\t    (q != NULL) ? (int)q->p_childrencnt : -1);\n"
            "\t\tboot_progress_stage(umi_msg);\n"
            "\t\tproc_list_unlock();\n"
            "\t\treturn ECHILD;\n",
        ),
        (
            "\t/* No child processes that could possibly satisfy the request? */\n"
            "\n"
            "\tif (nfound == 0) {\n"
            "\t\tproc_list_unlock();\n"
            "\t\treturn ECHILD;\n",
            "\t/* No child processes that could possibly satisfy the request? */\n"
            "\n"
            "\tif (nfound == 0) {\n"
            "\t\tchar umi_msg[96];\n"
            "\n"
            "\t\t(void)snprintf(umi_msg, sizeof(umi_msg),\n"
            "\t\t    \"WAIT4 B none pid=%d cnt=%d\",\n"
            "\t\t    (q != NULL) ? (int)q->p_pid : -1,\n"
            "\t\t    (q != NULL) ? (int)q->p_childrencnt : -1);\n"
            "\t\tboot_progress_stage(umi_msg);\n"
            "\t\tproc_list_unlock();\n"
            "\t\treturn ECHILD;\n",
        ),
        (
            "\tpg = pgrp_leave_locked(child);\n"
            "\tLIST_REMOVE(child, p_list);\n"
            "\tparent->p_childrencnt--;\n",
            "\tpg = pgrp_leave_locked(child);\n"
            "\tLIST_REMOVE(child, p_list);\n"
            "\tparent->p_childrencnt--;\n"
            "\t/* UMI bring-up: a REAP line before any EL0 IN svc=1 says the child was\n"
            "\t * reaped without the parent ever waiting, which is the signature of the\n"
            "\t * dead-parent path in fork(). */\n"
            "\t{\n"
            "\t\tchar umi_msg[96];\n"
            "\n"
            "\t\t(void)snprintf(umi_msg, sizeof(umi_msg),\n"
            "\t\t    \"REAP cpid=%d ppid=%d fl=%d\", child->p_pid, parent->p_pid,\n"
            "\t\t    (int)flags);\n"
            "\t\tboot_progress_stage(umi_msg);\n"
            "\t}\n",
        ),
    ],
}

for rel, pairs in edits.items():
    p = work / "b" / rel
    text = p.read_text()
    for i, (old, new) in enumerate(pairs):
        n = text.count(old)
        assert n == 1, (rel, i, "anchor-count", n)
        text = text.replace(old, new)
    p.write_text(text)
    print("edited", rel)
PY
[ $? -eq 0 ] || { echo "EDIT-FAIL"; rm -rf "$WORK"; exit 1; }

echo
echo "== 2. diff =="
{
  echo "--- a/bsd/kern/kern_fork.c"
  echo "+++ b/bsd/kern/kern_fork.c"
  ( cd "$WORK" && diff -u "a/bsd/kern/kern_fork.c" "b/bsd/kern/kern_fork.c" ) | tail -n +3
  echo "--- a/bsd/kern/kern_exit.c"
  echo "+++ b/bsd/kern/kern_exit.c"
  ( cd "$WORK" && diff -u "a/bsd/kern/kern_exit.c" "b/bsd/kern/kern_exit.c" ) | tail -n +3
} | tee "$WORK/body.diff"

echo
echo "== 3. 落盘 =="
cp "$WORK/body.diff" "$DEV/patches/umi-xnu/$NAME"
cp "$WORK/body.diff" "$ARCH/$NAME"
ls -la "$DEV/patches/umi-xnu/$NAME" "$ARCH/$NAME"
sha256sum "$DEV/patches/umi-xnu/$NAME" "$ARCH/$NAME"

echo
echo "== 4. 真实打回基线（不只 dry-run），并核新串在不在 =="
( cd "$X" && patch -p1 < "$DEV/patches/umi-xnu/$NAME" ) && echo "APPLY-OK" || echo "APPLY-FAIL"
grep -n 'WAIT4 A none\|WAIT4 B none' "$X/bsd/kern/kern_exit.c"
grep -c 'FORK cpid=\|FORK deadparent-reap\|FORK child-woken' "$X/bsd/kern/kern_fork.c"

echo
echo "== 5. CRLF 检查 =="
for f in "$DEV/patches/umi-xnu/$NAME" "$ARCH/$NAME"; do
  printf '%s CR=%s\n' "$f" "$(tr -dc '\r' < "$f" | wc -c)"
done

echo
echo "== 6. 重放顺序确认（25z 必须紧跟 24z 之后）=="
ls "$DEV/patches/umi-xnu/" | grep '^z' | sort | tail -4
rm -rf "$WORK"
echo done

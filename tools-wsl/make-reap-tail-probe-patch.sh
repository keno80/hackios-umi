#!/bin/bash
# 落成 umi-reap-tail-probe 补丁（27z）：把 reap_child_locked 尾段与 wait4 成功返回切成 5 段上屏。
# 依据（run-26 实测）：FORK cx0=0 之后子进程真的进 EL0 调了 exit（EL0 IN svc=1），
#   父进程也醒了、也走到 REAP cpid=2 ppid=1 fl=0（该探针在 wait4_nocancel:3073 的
#   reap_child_locked(q, p, reap_flags) 里），但屏上再也没有 EL0 OUT svc=7——
#   也就是 reap 之后、返回用户态之前这一段挂住了。reap_child_locked 尾段里有
#   phash_remove_locked / proc_checkdeadrefs / pgrp_rele / fdt_destroy / proc_wait_release
#   这几个会等锁或等引用的调用，逐个切开才知道停在哪一个。
set -uo pipefail
OUT=/mnt/e/Code/HackIos/out/probes/p-make-reap-tail-probe-patch.txt
: > "$OUT"
exec >>"$OUT" 2>&1

WS=/home/unixnu/code/umi-work-pin
X=$WS/out/umi-xnu/umi/tree/.cache/xnu-work
DEV=/home/unixnu/code/UniXNU-umi
ARCH=/mnt/e/Code/HackIos/patches/umi-xnu
NAME=zzzzzzzzzzzzzzzzzzzzzzzzzzz-umi-reap-tail-probe.patch

echo "== 0. 基线必须已含 25z 的 REAP 探针（锚点是打过 25z 的文本）=="
C=$(grep -c 'REAP cpid=' "$X/bsd/kern/kern_exit.c")
echo "25z REAP 标记计数=$C"
if [ "$C" = "0" ]; then
  echo "== 0a. 基线没 25z，先正向打上 =="
  ( cd "$X" && patch -p1 < "$DEV/patches/umi-xnu/zzzzzzzzzzzzzzzzzzzzzzzzz-umi-fork-probe.patch" ) \
    && echo "PRE-APPLY-OK" || { echo "PRE-APPLY-FAIL"; exit 1; }
  grep -c 'REAP cpid=' "$X/bsd/kern/kern_exit.c"
fi
D=$(grep -c 'FORK cx0=0' "$X/bsd/kern/kern_fork.c")
echo "26z 标记计数=$D"
if [ "$D" = "0" ]; then
  echo "== 0b. 基线没 26z，先正向打上 =="
  ( cd "$X" && patch -p1 < "$DEV/patches/umi-xnu/zzzzzzzzzzzzzzzzzzzzzzzzzz-umi-fork-child-zero.patch" ) \
    && echo "PRE-APPLY-26-OK" || { echo "PRE-APPLY-26-FAIL"; exit 1; }
fi
echo "-- 若上一轮已打过 27z，先剥掉回到 26z 态 --"
if grep -q 'REAP unlocked' "$X/bsd/kern/kern_exit.c"; then
  ( cd "$X" && patch -R -p1 < "$DEV/patches/umi-xnu/$NAME" ) && echo "REVERSED-OK" \
    || { echo "REVERSE-FAIL"; exit 1; }
fi

echo
echo "== 1. 生成 =="
WORK=$(mktemp -d)
mkdir -p "$WORK/a/bsd/kern" "$WORK/b/bsd/kern"
cp "$X/bsd/kern/kern_exit.c" "$WORK/a/bsd/kern/"
cp "$X/bsd/kern/kern_exit.c" "$WORK/b/bsd/kern/"

python3 - "$WORK" <<'PY'
import pathlib, sys

work = pathlib.Path(sys.argv[1])
rel = "bsd/kern/kern_exit.c"

edits = [
    # 1) phash_remove/proc_checkdeadrefs 之后
    ("\tproc_checkdeadrefs(child);\n\tnprocs--;\n",
     "\tproc_checkdeadrefs(child);\n"
     "\tboot_progress_stage(\"REAP deadrefs-ok\");\n"
     "\tnprocs--;\n"),
    # 2) 放开 proc_list_lock，然后 pgrp_rele / fdt_destroy
    ("\tproc_list_unlock();\n\n\tpgrp_rele(pg);\n\tfdt_destroy(child);\n",
     "\tproc_list_unlock();\n"
     "\tboot_progress_stage(\"REAP unlocked\");\n\n"
     "\tpgrp_rele(pg);\n"
     "\tboot_progress_stage(\"REAP pgrp-rele-ok\");\n"
     "\tfdt_destroy(child);\n"
     "\tboot_progress_stage(\"REAP fdt-destroy-ok\");\n"),
    # 3) proc_wait_release 之后（这一步会等 proc 引用归零）
    ("\tlck_spin_destroy(&child->p_slock, &proc_slock_grp);\n"
     "\tproc_wait_release(child);\n",
     "\tlck_spin_destroy(&child->p_slock, &proc_slock_grp);\n"
     "\tproc_wait_release(child);\n"
     "\tboot_progress_stage(\"REAP wait-release-ok\");\n"),
    # 4) wait4 收完孩子、准备 return 0（回 EL0 前最后一站）
    ("\t\t\t(void)reap_child_locked(q, p, reap_flags);\n\n\t\t\treturn 0;\n",
     "\t\t\t(void)reap_child_locked(q, p, reap_flags);\n"
     "\t\t\tboot_progress_stage(\"WAIT4 reaped-return\");\n\n"
     "\t\t\treturn 0;\n"),
]

p = work / "b" / rel
text = p.read_text()
for i, (old, new) in enumerate(edits):
    n = text.count(old)
    assert n == 1, (i, "anchor-count", n)
    text = text.replace(old, new)
p.write_text(text)
print("edited", rel, "edits=", len(edits))
PY
[ $? -eq 0 ] || { echo "EDIT-FAIL"; rm -rf "$WORK"; exit 1; }

echo
echo "== 2. diff =="
{
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
echo "== 4. 真实打回基线并核串 =="
( cd "$X" && patch -p1 < "$DEV/patches/umi-xnu/$NAME" ) && echo "APPLY-OK" || echo "APPLY-FAIL"
grep -n 'REAP deadrefs-ok\|REAP unlocked\|REAP pgrp-rele-ok\|REAP fdt-destroy-ok\|REAP wait-release-ok\|WAIT4 reaped-return' "$X/bsd/kern/kern_exit.c"

echo
echo "== 5. CRLF 检查 =="
for f in "$DEV/patches/umi-xnu/$NAME" "$ARCH/$NAME"; do
  printf '%s CR=%s\n' "$f" "$(tr -dc '\r' < "$f" | wc -c)"
done

echo
echo "== 6. 重放顺序（27z 必须紧跟 26z）=="
ls "$DEV/patches/umi-xnu/" | grep '^z' | sort | tail -4
rm -rf "$WORK"
echo done

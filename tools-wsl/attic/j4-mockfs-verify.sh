#!/bin/bash
# J4：等 mockfs+探针档内核编完，做「假根驱动真的进链」的静态验收
set -u
OUT=/mnt/e/Code/HackIos/out/probes/j4-mockfs-verify.txt
: > "$OUT"
exec >>"$OUT" 2>&1

LOGD=/home/unixnu/code/UniXNU-main/out/unixnu-logs
WS=/home/unixnu/code/umi-work-pin
K=$WS/out/umi-xnu/umi/kernel/source-kernel.macho
X=$WS/out/umi-xnu/umi/tree/.cache/xnu-work

PID=$(cat "$LOGD/kernel-mockfs.pid" 2>/dev/null || echo "")
L=$(cat "$LOGD/kernel-mockfs-latest.txt" 2>/dev/null || echo "")
echo "== 0. 等待 pid=$PID 退出，日志 $L =="
start=$(date +%s)
while [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; do
  sleep 20
  echo "[$(( $(date +%s) - start )) s] $(tail -1 "$L" 2>/dev/null | cut -c1-140)"
done
echo "== 构建结束，用时 $(( $(date +%s) - start )) s =="
tail -25 "$L"
echo
echo "== 1. 产物 =="
ls -la "$K"
sha256sum "$K"
echo
echo "== 2. 假根驱动进链的三条判据 =="
VOBJ=$X/../build/xnu/ios-obj/DEVELOPMENT_ARM64_BCM2837/bsd/DEVELOPMENT/vfs_conf.o
[ -f "$VOBJ" ] || VOBJ=$(find $WS/out/umi-xnu -name vfs_conf.o | head -1)
echo "vfs_conf.o = $VOBJ"
echo "  .source-mockfs-mode = $(cat "$(dirname "$VOBJ")/.source-mockfs-mode" 2>/dev/null || echo none)"
echo "  vfs_conf.o 里 mockfs 字符串 = $(strings -a "$VOBJ" 2>/dev/null | grep -c mockfs)"
echo "  内核里 mockfs 字符串 = $(strings -a "$K" | grep -c mockfs)"
echo "  内核里 'mockfs' 精确名 = $(strings -a "$K" | grep -xc mockfs)"
echo "  内核里 mockfs_mountroot = $(strings -a "$K" | grep -c mockfs_mountroot)"
echo
echo "== 3. 探针六条仍在 =="
for s in 'CMDLINE %s' 'SETCONF iombr=' 'MOUNTFAIL err=' 'MR bdevvp=' 'MR exhausted last=' 'MR %s=%d'; do
  printf '  %-24s hit=%s\n' "$s" "$(strings -a "$K" | grep -cF "$s")"
done
echo "  工作树 boot_progress_stage(umi_msg) = $(grep -rc 'boot_progress_stage(umi_msg)' $X/bsd/kern/bsd_init.c $X/bsd/vfs/vfs_subr.c | tr '\n' ' ')"
echo
echo "== 4. 上一档 trace 内核对照（应仍是 0）=="
T=$WS/out/umi-xnu/umi/kernel/entry-trace-kernel.macho
echo "  trace 档 mockfs = $(strings -a "$T" | grep -c mockfs)"
echo
echo "== 5. 判定 =="
m=$(strings -a "$K" | grep -c mockfs)
[ "$m" -ge 50 ] && echo "MOCKFS-IN-KERNEL OK ($m)" || echo "MOCKFS-IN-KERNEL FAIL ($m)"
echo "DONE"

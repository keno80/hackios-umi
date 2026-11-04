#!/bin/bash
# R 步之二：28z 内核（zidx panic 屏上判据）的 QEMU 回归——确认 23 发走查没被 28z 改坏。
# 判据口径：除 N/Q 步那九组串外，还必须见到 UMI28 nz=（28z 探针真进了产物）；
#           屏上判据：EL0 IN/OUT 发数与 run-29 同源，缺行即回归失败，不许出真机档。
set -uo pipefail
OUT=/mnt/e/Code/HackIos/out/probes/n2-qemu-regress-28z.txt
: > "$OUT"
exec >>"$OUT" 2>&1

WS=/home/unixnu/code/umi-work-pin
LOGD=/home/unixnu/code/UniXNU-main/out/unixnu-logs
K=$WS/out/umi-xnu/umi/kernel/source-kernel.macho
IMG=/mnt/e/Code/HackIos/out/fixtures/launchd-walk.macho
NAME=run-30-zidx28
EXPECT_SHA=9222c920ff3125c2fc0033a4d2b9b167436e9b75fa221f5ff550e179b538fb45

echo "== 1. 产物身份 =="
sha256sum "$K"
S=$(strings -a "$K")
for pat in 'UMI28 nz=' 'EL0 IN svc=' 'EL0 OUT svc=' 'FORK cpid=' 'FORK cx0=0' 'REAP cpid=' 'WAIT4 reaped-return' 'INIT exec ok' 'MR exhausted last='; do
  printf '%-24s %s\n' "$pat" "$(printf '%s' "$S" | grep -c "$pat")"
done
MISS=0
for pat in 'UMI28 nz=' 'EL0 IN svc=' 'EL0 OUT svc=' 'FORK cpid=' 'REAP cpid=' 'WAIT4 reaped-return'; do
  c=$(printf '%s' "$S" | grep -c "$pat")
  [ "$c" -ge 1 ] || { echo "MISSING $pat"; MISS=1; }
done
[ "$MISS" -eq 0 ] || { echo "== 拒绝跑 QEMU：28z 或走查探针不在产物里"; exit 1; }
sha256sum "$K" | grep -q "^$EXPECT_SHA" || echo "WARN sha 与 r9 核账那份不一致（可能又重编过）"

echo
echo "== 2. 跑 QEMU（走查件，23 发）=="
RUN=$WS/out/umi-qemu/$NAME
[ -e "$RUN" ] && rm -rf "$RUN"
cd /mnt/e/Code/HackIos || exit 1
setsid nohup bash tools-wsl/run-umi-qemu.sh "$NAME" \
  --mockfs-initrd "$IMG" \
  --args "-v keepsyms=1 kt_fixed_zones=120" \
  --capture-screen --timeout 150 \
  > "$LOGD/qemu-$NAME.launch.log" 2>&1 &
echo "launcher pid=$!"

echo
echo "== 3. 等退出（最多 900s）=="
for i in $(seq 1 180); do
  grep -q 'run_umi_qemu exit=' "$LOGD/qemu-$NAME.launch.log" 2>/dev/null && { echo "DONE after $((i*5))s"; break; }
  sleep 5
done
tail -3 "$LOGD/qemu-$NAME.launch.log"

echo
echo "== 4. 取回屏 =="
cp "$RUN/screen.png" /mnt/e/Code/HackIos/out/screens/qemu-$NAME.png 2>/dev/null && \
  sha256sum /mnt/e/Code/HackIos/out/screens/qemu-$NAME.png || echo NO-SCREEN

echo
echo "== 5. uart 里走查链（逐行）=="
grep -aE "EL0 (IN|OUT|MACH)|FORK|REAP|WAIT4|INIT exec|UMI28|PANIC" "$RUN/gdb-uart.log" 2>/dev/null | tail -60
echo "--- 计数 ---"
for pat in 'EL0 IN svc=' 'EL0 OUT svc=' 'EL0 MACH svc=' 'UMI28 nz=' 'PANIC'; do
  printf '%-18s %s\n' "$pat" "$(grep -ac "$pat" "$RUN/gdb-uart.log" 2>/dev/null)"
done
echo "== done $(date -u +%FT%TZ)"

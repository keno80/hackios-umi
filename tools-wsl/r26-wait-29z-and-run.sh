#!/bin/bash
# R 步之三：等 29z 内核编完 → 静态核账（nm 里必须有 umi_el0_mach_seen / umi_el0_mach_out_seen 两张表，
# 这是 29z 真进产物的唯一硬证据；strings 只能证明 IN/OUT 串还在）→ 用带 mach 段的走查件跑 QEMU → 取回屏。
# 判据口径：屏上应出现 9 行负号 svc 的 EL0 IN/OUT 对；缺哪一对，哪发 mach trap 就是新闸。
set -uo pipefail
OUT=/mnt/e/Code/HackIos/out/probes/r26-wait-29z-and-run.txt
: > "$OUT"
exec >>"$OUT" 2>&1

WS=/home/unixnu/code/umi-work-pin
LOGD=/home/unixnu/code/UniXNU-main/out/unixnu-logs
K=$WS/out/umi-xnu/umi/kernel/source-kernel.macho
IMG=/mnt/e/Code/HackIos/out/fixtures/launchd-walk.macho
NAME=run-31-mach
MARK=/tmp/walk-start-marker
OLD_SHA=9222c920ff3125c2fc0033a4d2b9b167436e9b75fa221f5ff550e179b538fb45
source /usr/local/bin/unixnu-env 2>/dev/null
TC=${UNIXNU_TOOLCHAIN:-/opt/unixnu-linux}
NM=$TC/CommandLineTools/usr/bin/nm

echo "== 1. 等构建结束（最多 3600s）=="
P=$(cat "$LOGD/kernel-walk.pid" 2>/dev/null)
for i in $(seq 1 120); do
  if ! kill -0 "$P" 2>/dev/null; then echo "BUILD-DONE after $((i*30))s pid=$P"; break; fi
  sleep 30
done
kill -0 "$P" 2>/dev/null && { echo "BUILD-STILL-RUNNING 放弃"; exit 1; }

echo
echo "== 2. 构建日志尾 =="
L=$(cat "$LOGD/kernel-walk-latest.txt")
sed -e 's/\x1b\[[0-9;]*[A-Za-z]//g' "$L" 2>/dev/null | tail -16

echo
echo "== 3. 产物新鲜度与身份 =="
ls -la "$K"; sha256sum "$K"
[ "$K" -nt "$MARK" ] && echo "FRESH-OK" || echo "STALE-KERNEL"
sha256sum "$K" | grep -q "^$OLD_SHA" && { echo "SHA-UNCHANGED：29z 没进产物，拒绝跑"; exit 1; }

echo
echo "== 4. 29z 硬证据：nm 里两张 mach 去重表 =="
"$NM" "$K" 2>/dev/null | grep -i "umi_el0_mach" | head
MS=$("$NM" "$K" 2>/dev/null | grep -c 'umi_el0_mach_seen')
MO=$("$NM" "$K" 2>/dev/null | grep -c 'umi_el0_mach_out_seen')
printf 'mach_seen=%s mach_out_seen=%s\n' "$MS" "$MO"
# 注意：这里不能用 `nm | grep -q`——pipefail 下 grep 命中即关管道，nm 收到 SIGPIPE 返回 141，
# 整条管道被判失败，会把「符号其实在」读成假阴性（本轮就是这么差点白等一次）。
MISS=0
[ "$MS" -ge 1 ] || { echo "MISSING umi_el0_mach_seen"; MISS=1; }
[ "$MO" -ge 1 ] || { echo "MISSING umi_el0_mach_out_seen"; MISS=1; }

echo
echo "== 5. 回归核账（走查/挂根/28z 探针都必须在）=="
S=$(strings -a "$K")
for pat in 'UMI28 nz=' 'EL0 IN svc=' 'EL0 OUT svc=' 'FORK cpid=' 'FORK cx0=0' 'REAP cpid=' 'WAIT4 reaped-return' 'INIT exec ok' 'MR exhausted last='; do
  printf '%-24s %s\n' "$pat" "$(printf '%s' "$S" | grep -c "$pat")"
done
for pat in 'UMI28 nz=' 'EL0 IN svc=' 'EL0 OUT svc=' 'FORK cpid=' 'REAP cpid=' 'WAIT4 reaped-return'; do
  c=$(printf '%s' "$S" | grep -c "$pat")
  [ "$c" -ge 1 ] || { echo "MISSING $pat"; MISS=1; }
done
[ "$MISS" -eq 0 ] || { echo "== 拒绝跑 QEMU：探针不在产物里"; exit 1; }

echo
echo "== 6. 走查件身份（必须带 mach 段）=="
sha256sum "$IMG"
printf 'Q-PIPE-PAYLOAD=%s\n' "$(strings -a "$IMG" | grep -c -F 'UMI-WALK-Q-PIPE-PAYLOAD')"

echo
echo "== 7. 跑 QEMU =="
RUN=$WS/out/umi-qemu/$NAME
[ -e "$RUN" ] && rm -rf "$RUN"
cd /mnt/e/Code/HackIos || exit 1
setsid nohup bash tools-wsl/run-umi-qemu.sh "$NAME" \
  --mockfs-initrd "$IMG" \
  --args "-v keepsyms=1 kt_fixed_zones=120" \
  --read-user-address 100004040:256 \
  --read-user-address 100004140:256 \
  --capture-screen --timeout 170 \
  > "$LOGD/qemu-$NAME.launch.log" 2>&1 &
echo "launcher pid=$!"

echo
echo "== 8. 等退出（最多 900s）=="
for i in $(seq 1 180); do
  grep -q 'run_umi_qemu exit=' "$LOGD/qemu-$NAME.launch.log" 2>/dev/null && { echo "DONE after $((i*5))s"; break; }
  sleep 5
done
tail -3 "$LOGD/qemu-$NAME.launch.log"

echo
echo "== 9. 取回屏与现场 =="
cp "$RUN/screen.png" /mnt/e/Code/HackIos/out/screens/qemu-$NAME.png 2>/dev/null && \
  sha256sum /mnt/e/Code/HackIos/out/screens/qemu-$NAME.png || echo NO-SCREEN
cp "$RUN/gdb-stop.json" "/mnt/e/Code/HackIos/out/probes/$NAME-gdb-stop.json" 2>/dev/null && \
  echo "copied $NAME-gdb-stop.json" || echo NO-JSON-COPY
echo "== done $(date -u +%FT%TZ)"

#!/bin/bash
# M 步：等 24z+23z 内核编完 → 静态验收 → 用走查件跑 QEMU → 取回屏与现场。
# 判据口径：内核里必须同时有 EL0 IN / EL0 OUT 两个新串，否则拒绝跑（白跑几十分钟）。
set -uo pipefail
OUT=/mnt/e/Code/HackIos/out/probes/m19-wait-and-run.txt
: > "$OUT"
exec >>"$OUT" 2>&1

WS=/home/unixnu/code/umi-work-pin
LOGD=/home/unixnu/code/UniXNU-main/out/unixnu-logs
K=$WS/out/umi-xnu/umi/kernel/source-kernel.macho
IMG=/mnt/e/Code/HackIos/out/fixtures/launchd-walk.macho
NAME=run-22-walk2
MARK=/tmp/walk-start-marker

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
sed -e 's/\x1b\[[0-9;]*[A-Za-z]//g' "$L" 2>/dev/null | tail -12

echo
echo "== 3. 产物新鲜度 =="
ls -la "$K"
[ "$K" -nt "$MARK" ] && echo "FRESH-OK" || echo "STALE-KERNEL"

echo
echo "== 4. 静态验收（strings 计数）=="
S=$(strings -a "$K")
for pat in 'EL0 IN svc=' 'EL0 OUT svc=' 'EL0 MACH svc=' 'INIT exec ok' 'INIT returned' 'vfs_mountroot mounted'; do
  printf '%-24s %s\n' "$pat" "$(printf '%s' "$S" | grep -c "$pat")"
done
IN=$(printf '%s' "$S" | grep -c 'EL0 IN svc=')
OT=$(printf '%s' "$S" | grep -c 'EL0 OUT svc=')
if [ "$IN" -lt 1 ] || [ "$OT" -lt 1 ]; then
  echo "== 拒绝跑 QEMU：内核缺 EL0 IN/OUT 探针"
  exit 1
fi
sha256sum "$K"

echo
echo "== 5. 跑 QEMU（走查件）=="
RUN=$WS/out/umi-qemu/$NAME
[ -e "$RUN" ] && rm -rf "$RUN"
cd /mnt/e/Code/HackIos || exit 1
setsid nohup bash tools-wsl/run-umi-qemu.sh "$NAME" \
  --mockfs-initrd "$IMG" \
  --args "-v keepsyms=1 kt_fixed_zones=120" \
  --read-user-address 100004040:96 \
  --read-user-address 1000040c0:96 \
  --capture-screen --timeout 150 \
  > "$LOGD/qemu-$NAME.launch.log" 2>&1 &
echo "launcher pid=$!"

echo
echo "== 6. 等 run_umi_qemu 退出（最多 900s）=="
for i in $(seq 1 180); do
  if grep -q 'run_umi_qemu exit=' "$LOGD/qemu-$NAME.launch.log" 2>/dev/null; then
    echo "DONE after $((i*5))s"; break
  fi
  sleep 5
done
tail -3 "$LOGD/qemu-$NAME.launch.log"

echo
echo "== 7. 取回屏 =="
cp "$RUN/screen.png" /mnt/e/Code/HackIos/out/screens/qemu-$NAME.png 2>/dev/null && \
  sha256sum /mnt/e/Code/HackIos/out/screens/qemu-$NAME.png || echo NO-SCREEN

echo
echo "== 8. 现场关键字段 =="
python3 -c "
import json
r=json.load(open('$RUN/gdb-stop.json'))
for k in ['pc','x0','stop','bounded_timeout_interrupted','stop_symbol','kernel_sha256']:
    print(k,'=',r.get(k))
print('system_registers=',json.dumps(r.get('system_registers',{})))
print('memory=',json.dumps(r.get('memory',{}))[:800])
" 2>/dev/null || echo NO-JSON

echo
echo "== 9. uart 尾 =="
tail -8 "$RUN/gdb-uart.log" 2>/dev/null
echo "== done $(date -u +%FT%TZ)"

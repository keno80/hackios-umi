#!/bin/bash
# QEMU 深推：复用昨晚跑通的 run-umi-qemu（它导出 UniXNU 定制工具链 PATH，xcrun nm 才认 Mach-O），
# 只额外注入作者的 kt_fixed_zones=120。纯本地，不碰手机。
set -uo pipefail
W=/home/unixnu/code/umi-work-pin
NAME=${1:-run-04-zones}
ARGS=${2:--v keepsyms=1 kt_fixed_zones=120}
TIMEOUT=${TIMEOUT:-150}
OUT=$W/out/umi-qemu/$NAME
RUNNER_LOG=/home/unixnu/code/UniXNU-main/out/unixnu-logs/qemu-$NAME.log
STATE=$W/out/tui-state

cat > "$STATE" <<EOF
PHASE=qemu
RUN=$NAME
TOOL=tcg / cortex-a710 / 256MiB
LOG=$OUT/gdb-uart.log
START_TS=$(date +%s)
NOTE1=闸 kalloc.c:1779 n_zones_sig+n_zones_type+1<=32 → 本次带 kt_fixed_zones=120
NOTE2=args=$ARGS  timeout=${TIMEOUT}s
TASK1=done|#5 源码内核基线 18,409,640B 已产出
TASK2=run|#12 QEMU 深推 kt_fixed_zones=120（本次 $NAME）
TASK3=wait|#13 下一个停点归因（assert / _IOFindBSDRoot / 空闲）
TASK4=gate|#9 真机只读采集（按你要求暂停，未动手机）
EOF

command -v run-umi-qemu > /dev/null || { echo "缺 run-umi-qemu 助手"; echo "PHASE=error" >> "$STATE"; exit 1; }
if [ -e "$OUT" ]; then echo "$OUT 已存在（拒绝覆盖），换名字"; echo "PHASE=error" >> "$STATE"; exit 1; fi

echo "== 启动 $NAME  args=[$ARGS]  timeout=${TIMEOUT}s"
run-umi-qemu "$NAME" "--args=$ARGS" --timeout "$TIMEOUT"
rc=$?
echo "PID=$$" >> "$STATE"
echo "== run-umi-qemu rc=$rc"
echo "== run 目录"
ls -l "$OUT" 2>/dev/null | awk 'length($0)<200' | tail -12
echo "== runner 日志尾部"
awk 'length($0)<300' "$RUNNER_LOG" 2>/dev/null | tail -20 | sed 's/^/  | /'
echo "== uart 尾部（内核自己的输出）"
awk 'length($0)<300' "$OUT/gdb-uart.log" 2>/dev/null | tail -20 | sed 's/^/  | /'
echo "  uart 行数=$(wc -l < "$OUT/gdb-uart.log" 2>/dev/null || echo 0)"
echo "== 与基线 run-01 对比"
for r in run-01 "$NAME"; do
  f=$W/out/umi-qemu/$r/gdb-stop.json
  if [ -f "$f" ]; then
    python3 - "$f" "$r" <<'PY'
import json, sys
f, tag = sys.argv[1], sys.argv[2]
d = json.load(open(f))
keys = [k for k in ("stop_symbol", "symbol", "pc", "address", "timeout",
                    "bounded_timeout_interrupted", "interrupted", "target_hits", "hits") if k in d]
print(f"  {tag}: " + ", ".join(f"{k}={str(d[k])[:60]}" for k in keys))
regs = d.get("registers") or {}
if isinstance(regs, dict):
    got = {k: regs[k] for k in ("pc", "x0", "x1", "x2", "lr") if k in regs}
    if got:
        print("      regs: " + ", ".join(f"{k}={str(v)[:18]}" for k, v in got.items()))
bt = d.get("backtrace") or d.get("frames")
if bt:
    print("      bt: " + str(bt)[:400])
PY
  else
    echo "  $r: 无 gdb-stop.json"
  fi
done
echo "PHASE=qemu-done" >> "$STATE"
echo "NOTE3=rc=$rc；uart 行数=$(wc -l < "$OUT/gdb-uart.log" 2>/dev/null || echo 0)" >> "$STATE"
echo DONE

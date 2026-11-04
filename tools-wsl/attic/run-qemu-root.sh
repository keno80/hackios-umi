#!/bin/bash
# 阶段6：带上 userdata-root 的 OS/SystemOS 窗口，让 QEMU 里的源码内核真挂根
# 复用 run-umi-qemu（导出定制工具链 PATH，xcrun nm 才认 Mach-O）；argparse 后者覆盖默认值
set -uo pipefail
W=/home/unixnu/code/umi-work-pin
NAME=${1:-run-05-root}
ARGS=${2:--v keepsyms=1 kt_fixed_zones=120}
TIMEOUT=${TIMEOUT:-600}
MEM=${MEM:-512}
OUT=$W/out/umi-qemu/$NAME
STATE=$W/out/tui-state

command -v run-umi-qemu > /dev/null || { echo "缺 run-umi-qemu 助手"; exit 1; }
[ -e "$OUT" ] && { echo "$OUT 已存在（拒绝覆盖），换名字"; exit 1; }
MAN=$W/out/umi-xnu/umi/userdata/userdata-root.json
IMG=$W/out/umi-xnu/umi/userdata/userdata-root.img
[ -f "$MAN" ] && [ -f "$IMG" ] || { echo "根卷还没产出：$MAN"; exit 1; }
python3 - "$MAN" <<'PY' || exit 1
import json, sys
m = json.load(open(sys.argv[1]))
need = {"image", "windows"}
missing = need - set(m)
if missing: sys.exit(f"清单缺字段 {missing}")
names = {w["name"] for w in m["windows"]}
if not {"OS", "SystemOS"} <= names: sys.exit(f"清单窗口不足：{names}")
print("清单 OK:", [(w["name"], w["offset"], w["size"]) for w in m["windows"]])
PY

cat > "$STATE" <<EOF
PHASE=qemu
RUN=$NAME
TOOL=tcg / cortex-a710 / ${MEM}MiB / 根卷窗口
LOG=$OUT/gdb-uart.log
START_TS=$(date +%s)
NOTE1=闸=_IOFindBSDRoot（缺根设备）→ 本次挂 OS+SystemOS 两个 virtio 只读盘
NOTE2=args=$ARGS  timeout=${TIMEOUT}s
TASK1=done|#14 userdata-root.img 已产出
TASK2=run|#14 QEMU 挂根（本次 $NAME）
TASK3=wait|挂根后的下一个停点归因
EOF

echo "== 启动 $NAME  args=[$ARGS] mem=$MEM timeout=$TIMEOUT"
run-umi-qemu "$NAME" "--args=$ARGS" --root-volume --systemos-volume --capture-screen \
  --owned-memory-mib "$MEM" --timeout "$TIMEOUT" &
child=$!
# 面板要能显示"在跑"并给出可终止的 PID：观察器 python 才是真正干活的进程
for _ in 1 2 3 4 5 6 7 8 9 10; do
  obs=$(pgrep -f "run_umi_qemu\.py.*umi-qemu/$NAME" | head -1)
  [ -n "$obs" ] && break
  sleep 0.5
done
echo "PID=${obs:-$child}" >> "$STATE"
wait "$child"
rc=$?
echo "== run_umi_qemu rc=$rc"
echo "== uart 尾部（内核自己的输出）"
awk 'length($0)<300' "$OUT/gdb-uart.log" 2>/dev/null | tail -30 | sed 's/^/  | /'
echo "  uart 行数=$(wc -l < "$OUT/gdb-uart.log" 2>/dev/null || echo 0)"
echo "== 停点 =="
[ -f "$OUT/gdb-stop.json" ] && head -c 1200 "$OUT/gdb-stop.json"
echo
echo "PHASE=qemu-done" >> "$STATE"
echo "NOTE3=rc=$rc；uart 行数=$(wc -l < "$OUT/gdb-uart.log" 2>/dev/null || echo 0)" >> "$STATE"
echo DONE

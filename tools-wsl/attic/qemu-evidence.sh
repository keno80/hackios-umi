#!/bin/bash
# 读一次 QEMU 运行的全部证据
D=/home/unixnu/code/umi-work-pin/out/umi-qemu/${1:-run-01}
echo "== 目录 $D"
ls -l "$D"
echo "== uart 全文"
cat "$D/gdb-uart.log"
echo "== runner.log"
cat "$D/runner.log" 2>/dev/null
echo "== gdb-stderr"
cat "$D/gdb-stderr.log" 2>/dev/null
echo "== gdb-stop.json 后半"
python3 - "$D/gdb-stop.json" <<'PY'
import json, sys
r = json.load(open(sys.argv[1]))
skip = {f"x{i}" for i in range(30)} | {"sp", "pc", "pstate", "stop"}
for k, v in r.items():
    if k in skip:
        continue
    s = json.dumps(v, ensure_ascii=False)
    if len(s) > 1200:
        s = s[:1200] + " ...[截断]"
    print(f"{k}: {s}")
PY
echo "== provenance.json"
cat "$D/provenance.json"

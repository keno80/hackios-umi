#!/bin/bash
OUT=/mnt/e/Code/HackIos/out/probes/menu-overlap3.txt
python3 - > "$OUT" 2>&1 <<'PY'
import sys
sys.path.insert(0, "/home/unixnu/code/umi-work-pin/tools")
from analyze_umi import fdt_nodes, reg_ranges
LO, HI = 0x9fc00000, 0x9fc00000 + 0x300000
tree = fdt_nodes(open("/mnt/e/Code/HackIos/out/phone3/running.dtb", "rb").read())
def rng(k):
    out = []
    for r in reg_ranges(tree, k):
        b = int(r["address"], 16) if isinstance(r["address"], str) else r["address"]
        out.append((b, r["size_bytes"]))
    return out
rm = sorted(k for k in tree if k.startswith("/reserved-memory/") and tree[k].get("reg"))
hit = []
print("--- 本机实机 DT reserved-memory（%d 个）---" % len(rm))
for k in rm:
    for b, s in rng(k):
        o = b < HI and b + s > LO
        if o:
            hit.append((k.split("/")[-1], hex(b), hex(s)))
        print("  %-46s %#012x..%#012x%s" % (k.split("/")[-1], b, b + s, "  <== 撞 FD 窗口" if o else ""))
print("--- memory 节点 ---")
for k in [x for x in tree if x.startswith("/memory")]:
    for b, s in rng(k):
        print("  %-20s %#x + %#x = ..%#x  (%.1f GB)" % (k, b, s, b + s, s / 2**30))
print("结论: reserved-memory 与 FD 窗口 [0x9fc00000..0x9ffffff] 重叠 =", hit or "无")
print("FD 窗口是否落在 memory 区间内:",
      any(b <= LO and HI <= b + s for k in [x for x in tree if x.startswith("/memory")] for b, s in rng(k)))
PY
echo WROTE >> "$OUT"

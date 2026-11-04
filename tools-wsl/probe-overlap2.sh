#!/bin/bash
OUT=/mnt/e/Code/HackIos/out/probes/menu-overlap2.txt
sed -n '77,110p' /home/unixnu/code/umi-work-pin/tools/analyze_umi.py > /tmp/rr.txt
python3 - > "$OUT" 2>&1 <<'PY'
import sys
sys.path.insert(0, "/home/unixnu/code/umi-work-pin/tools")
from analyze_umi import fdt_nodes, reg_ranges
LO, HI = 0x9fc00000, 0x9fc00000 + 0x300000
tree = fdt_nodes(open("/mnt/e/Code/HackIos/out/phone3/running.dtb", "rb").read())
sample = reg_ranges(tree, "/reserved-memory") if "/reserved-memory" in tree else None
rm = [k for k in tree if k.startswith("/reserved-memory/") and tree[k].get("reg")]
k0 = sorted(rm)[0]
print("reg_ranges 返回样例:", repr(reg_ranges(tree, k0))[:200], "节点:", k0)
hit = []
print("--- reserved-memory 全表 ---")
for k in sorted(rm):
    for r in reg_ranges(tree, k):
        d = r if isinstance(r, dict) else dict(zip(("address", "size"), r))
        b = d.get("address", d.get("base")); s = d.get("size", 0)
        o = b < HI and b + s > LO
        if o: hit.append((k, b, s))
        print("  %-48s %#012x..%#012x%s" % (k.split("/")[-1], b, b + s, "  <== 撞 FD 窗口" if o else ""))
print("--- memory 节点 ---")
for k in [x for x in tree if x.startswith("/memory")]:
    for r in reg_ranges(tree, k):
        d = r if isinstance(r, dict) else dict(zip(("address", "size"), r))
        print("  %-24s %#x + %#x = ..%#x" % (k, d["address"], d["size"], d["address"] + d["size"]))
print("结论: 与 FD 窗口 [0x9fc00000,0x9ffffff] 重叠的 reserved 节点 =", hit or "无")
PY
echo WROTE >> "$OUT"

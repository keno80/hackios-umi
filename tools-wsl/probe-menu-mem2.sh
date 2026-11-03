#!/bin/bash
# #10 前置 4：FD 窗口与 reserved-memory 真重叠判定（按 64bit reg 正确解析）+ report.json 由谁产
WS=/home/unixnu/code/umi-work-pin
DTS=/mnt/e/Code/HackIos/out/phone3/dt/running.dts
{
echo "== FD 窗口 0x9fc00000..0x9ffffff 与 reserved-memory 重叠判定"
python3 - <<'PYEOF' 2>&1 | head -40
import re
txt = open("/mnt/e/Code/HackIos/out/phone3/dt/running.dts", encoding="utf-8", errors="replace").read().splitlines()
LOW, HIGH = 0x9fc00000, 0x9fc00000 + 0x300000
stack, cells = [], {}
addr_cells = 2
for i, line in enumerate(txt):
    s = line.strip()
    if s.endswith("{"):
        name = s[:-1].strip()
        stack.append(name)
        m = re.search(r"#address-cells\s*=\s*<0x([0-9a-f]+)>", line)
        continue
    m = re.match(r"#address-cells\s*=\s*<0x([0-9a-fA-F]+)>", s)
    if m:
        stack[-1] = s.split("=")[0].strip()
        continue
    m = re.match(r'reg\s*=\s*<([^>]*)>', s)
    if m:
        vals = [int(x, 16) for x in re.findall(r'0x([0-9a-fA-F]+)', m.group(1))]
        # 按 2+2 组装
        path = "/".join(n for n in stack if n)
        for k in range(0, len(vals) - 3, 4):
            base = (vals[k] << 32) | vals[k+1]
            size = (vals[k+2] << 32) | vals[k+3]
            if size == 0 or size > 0x400000000:
                continue
            if base < HIGH and base + size > LOW:
                print(f"重叠! {path}  {base:#x}..{base+size:#x}")
            elif 0x9f000000 <= base <= 0xa1000000:
                print(f"邻近   {path}  {base:#x}..{base+size:#x}")
    if s == "};":
        if stack:
            stack.pop()
PYEOF

echo "== 谁写 report.json（采集件成件）"
grep -rIn "report.json" $WS/tools/collect_umi.py $WS/devices/umi/bringup/tools/collect_umi.py $WS/tools/*.py 2>/dev/null | head -12
echo "== 现有 out/umi 目录"
ls $WS/out/umi/ 2>&1 | head -15
echo "== bootimg 的 requires_kernel_header 用法"
grep -n "requires_kernel_header\|kernel_header\|kernel_path\|BootShim" $WS/sources/UniXNU/scripts/unixnu/bootimg.py | head -20
} > /mnt/e/Code/HackIos/out/menu-mem2.txt 2>&1
echo WROTE

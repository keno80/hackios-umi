#!/bin/bash
# #10 前置 2：证据目录是否成件 + FD 窗口 0x9fc00000..0x9ffffff 与实机保留内存是否冲突
{
echo "== 采集解包目录清单"
for d in /mnt/e/Code/HackIos/out/phone2 /mnt/e/Code/HackIos/out/phone3 /mnt/e/Code/HackIos/out/phone3/dt; do
  echo "-- $d"; ls $d 2>/dev/null | head -20
done
echo "== report.json 在哪"
find /mnt/e/Code/HackIos/out /mnt/e/Code/HackIos/phone-capture -maxdepth 3 -name 'report.json' 2>/dev/null | head -5
echo "== zip 里的条目（前 40）"
python3 - <<'PYEOF' 2>&1 | head -45
import zipfile
z = zipfile.ZipFile("/mnt/e/Code/HackIos/phone-capture/umi-capture-20261103T045237Z.zip")
for n in z.namelist()[:40]:
    i = z.getinfo(n)
    print(f"{i.file_size:>12} {n}")
PYEOF
echo "== running.dtb 里覆盖 0x9fc00000 的节点 + 全部 reserved-memory"
python3 - <<'PYEOF' 2>&1 | head -60
import struct
p = "/mnt/e/Code/HackIos/out/phone3/running.dtb"
d = open(p, "rb").read()
magic, total, toff, str_off, mem_rsv, ver, last_rsv, size_struct, name_off = struct.unpack_from(">9I", d, 0)[:9]
def nodes(blob):
    # 用 dtc 输出更稳，这里只做粗定位
    return blob
LOW, HIGH = 0x9fc00000, 0x9fc00000 + 0x300000
import subprocess, re
txt = subprocess.run(["dtc", "-I", "dtb", "-o", "-", p], capture_output=True, text=True).stdout
cur = None
for line in txt.splitlines():
    s = line.strip()
    if s.startswith("/") or s.endswith("{"):
        cur = s.split("{")[0].strip()
    m = re.match(r"reg\s*=\s*<(.*)>", s.rstrip(";"))
    if not m or cur is None:
        continue
    vals = [int(x, 16) for x in re.findall(r"0x([0-9a-fA-F]+)", m.group(1))]
    for i in range(0, len(vals) - 1, 2):
        base, size = vals[i], vals[i+1]
        if base < HIGH and base + size > LOW:
            print(f"冲突: {cur}  {base:#x}+{size:#x}")
        elif 0x90000000 <= base < 0xa1000000:
            print(f"邻近: {cur}  {base:#x}..{base+size:#x}")
PYEOF
echo "== 采集里的 iomem / meminfo 是否存过"
find /mnt/e/Code/HackIos/out/phone3 /mnt/e/Code/HackIos/phone-capture -iname '*iomem*' -o -iname '*meminfo*' 2>/dev/null | head -5
} > /mnt/e/Code/HackIos/out/menu-mem.txt 2>&1
echo WROTE

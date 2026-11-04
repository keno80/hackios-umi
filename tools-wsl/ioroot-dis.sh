#!/bin/bash
# 看 _IOFindBSDRoot+0xc00..0xd00 的真实指令与它引用的字符串
export PATH=/opt/unixnu-linux/CommandLineTools/usr/bin:/opt/unixnu-linux/bin:/usr/local/bin:/usr/bin:/bin
export LC_ALL=C
K=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/kernel/source-kernel.macho
{
  echo "== which"; command -v otool; command -v llvm-objdump; command -v objdump
  echo "== nm _IOFindBSDRoot"
  xcrun nm -n "$K" 2>/dev/null | grep -i -m3 IOKitRootDevice
  xcrun nm -n "$K" 2>/dev/null | awk '$3=="_IOFindBSDRoot"{print "real",$1}'
  echo "== disasm around +0xc00..0xd00 (llvm-objdump)"
  llvm-objdump --macho -d --start-address=0xfffffff00798bb00 --stop-address=0xfffffff00798bc40 "$K" 2>&1 | head -80
  echo "== strings in that window via cstring VA scan"
  python3 - "$K" <<'PY'
import re, subprocess, sys
from pathlib import Path
k = Path(sys.argv[1])
out = subprocess.run(["otool", "-l", str(k)], text=True, errors="replace").stdout
if not out:
    out = subprocess.run(["xcrun", "otool", "-l", str(k)], text=True, errors="replace").stdout
sects, cur = [], {}
for ln in out.splitlines():
    t = ln.strip()
    if t.startswith("sectname"):
        cur = {"name": t.split(None, 1)[1]}
    elif t.startswith("addr ") and "addr" not in cur:
        cur["addr"] = int(t.split()[1], 16)
    elif t.startswith("size") and "size" not in cur:
        cur["size"] = int(t.split()[1], 16)
    elif t.startswith("offset") and "offset" not in cur:
        cur["offset"] = int(t.split()[1])
        if "addr" in cur and cur.get("size"):
            sects.append(cur)
        cur = {}
print("sections:", [(s["name"], hex(s["addr"]), s["size"]) for s in sects if s["name"] in ("__cstring", "__const_cstrings", "__objc_classname")][:5])
raw = subprocess.run(["llvm-objdump", "--macho", "-d", "--start-address=0xfffffff00798bb00",
                      "--stop-address=0xfffffff00798bc60", str(k)], text=True, errors="replace").stdout
pages = {}
for ln in raw.splitlines():
    m = re.search(r"adrp\s+(x\d+), (0x[0-9a-f]+)", ln)
    if m:
        pages[m.group(1)] = int(m.group(2), 16)
        continue
    m = re.search(r"add\s+(x\d+), (x\d+), #?(0x[0-9a-f]+)", ln)
    if m and m.group(2) in pages:
        va = pages[m.group(2)] + int(m.group(3), 16)
        for s in sects:
            if s["addr"] <= va < s["addr"] + s["size"]:
                with open(k, "rb") as fh:
                    fh.seek(s["offset"] + (va - s["addr"]))
                    txt = fh.read(4096).split(b"\0")[0].decode("utf-8", "replace")
                if len(txt) > 3:
                    print(f"  {va:#x} [{s['name']}] {txt!r}")
                break
PY
} > /mnt/e/Code/HackIos/out/probes/ioroot-dis.txt 2>&1
echo WROTE

#!/bin/bash
set -u
M=/home/unixnu/code/Mu_Basecore
D=/home/unixnu/code/uefi-umi-b
echo "== 抛出 FILE_CASE_MISMATCH 的位置"
grep -rn "FILE_CASE_MISMATCH" "$M/BaseTools/Source/Python" --include=*.py | sed 's/^/  /'
echo "== 手写复现 edk2 的逐层大小写核对"
python3 - "$D" "$M" <<'PY'
import os, sys
d, m = sys.argv[1], sys.argv[2]
cands = [
    os.path.join(d, "Mu_Basecore/MdePkg/MdeLibs.dsc.inc"),
    os.path.join(m, "MdePkg/MdeLibs.dsc.inc"),
]
for p in cands:
    print(" 检查", p)
    path = os.path.abspath(p)
    bad = []
    while True:
        parent = os.path.dirname(path)
        base = os.path.basename(path)
        if not os.path.isdir(parent):
            print("   父目录不存在:", parent); break
        names = os.listdir(parent)
        if base in names:
            if path == os.path.join(parent, base):
                pass
            path = parent
            continue
        hit = [n for n in names if n.upper() == base.upper()]
        if hit:
            bad.append((os.path.join(parent, base), hit))
            break
        break
    # 同时核对整条链上每一段与 listdir 的字面一致
    chain = path
    segs = []
    while chain and chain != os.path.dirname(chain):
        parent = os.path.dirname(chain); base = os.path.basename(chain)
        if os.path.isdir(parent) and base not in os.listdir(parent):
            segs.append((chain, [n for n in os.listdir(parent) if n.upper() == base.upper()]))
        chain = parent
    print("   mismatch:", bad or "none")
    print("   链上差异:", segs or "none")
    print("   realpath:", os.path.realpath(p))
PY
echo "== /home/unixnu/code 下有没有大小写变体"
ls /home/unixnu/code | sed 's/^/  /'
echo DONE

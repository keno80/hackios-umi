#!/bin/bash
# 用 BaseTools 自己的 Edk2Path+PathClass 复现 FILE_CASE_MISMATCH
O=/mnt/e/Code/HackIos/out/edk2-case8.txt
PY=/home/unixnu/code/Mu_Basecore/BaseTools/Source/Python
WS=/home/unixnu/code/uefi-umi-b
PP="$WS:$WS/Platforms/Xiaomi:/home/unixnu/code/umi-work-pin/out/unixnu/umi/tree/package:/home/unixnu/code/Mu_Basecore:$WS/Common/Mu:$WS/Common/Mu_OEM_Sample:$WS/Silicon/Qualcomm:$WS/Silicon/Silicium"
{
echo "== gAllFiles 写入点"
grep -rn "gAllFiles" $PY/Common/Edk2Path.py $PY/Common/globalData.py $PY/Common/Misc.py 2>/dev/null | head -30
echo "== gCaseInsensitive 设定"
grep -rn "gCaseInsensitive" $PY/Common/Edk2Path.py $PY/Common/globalData.py $PY/Build/Common/*.py 2>/dev/null | head -20
echo "== 复现（用真实 PACKAGES_PATH）"
cd $PY && PKGPATH="$PP" python3 - <<'PYEOF' 2>&1 | head -80
import os, sys
sys.path.insert(0, os.getcwd())
from Common.Edk2Path import Edk2Path
from Common import globalData as G
from Common.Misc import PathClass
ws = "/home/unixnu/code/uefi-umi-b"
pp = os.environ["PKGPATH"].split(os.pathsep)
ecp = Edk2Path(ws, pp)
print("CaseInsensitive:", getattr(ecp, "CaseInsensitive", "n/a"))
print("gCaseInsensitive:", G.gCaseInsensitive)
al = G.gAllFiles or {}
print("gAllFiles size:", len(al))
for k, v in list(al.items()):
    if "MdeLibs.dsc.inc" in k:
        print("  KEY", k, "->", v)
p = PathClass("MdePkg/MdeLibs.dsc.inc", ws)
print("Validate(ws) ->", p.Validate(Type="DSC"))
for r in pp:
    if r.endswith("Mu_Basecore"):
        q = PathClass("MdePkg/MdeLibs.dsc.inc", r)
        print("Validate(%s) -> %s | File=%s Root=%s" % (r, q.Validate(Type="DSC"), q.File, q.Root))
PYEOF
} > $O 2>&1
echo WROTE

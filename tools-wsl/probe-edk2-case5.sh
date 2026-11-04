#!/bin/bash
set -u
OUT=/mnt/e/Code/HackIos/out/probes/edk2-case5.txt
MB=/home/unixnu/code/Mu_Basecore
{
  echo "== Misc.py 1555..1600"
  sed -n '1555,1600p' "$MB/BaseTools/Source/Python/Common/Misc.py"
  echo
  echo "== 该函数名（往上找 def）"
  awk 'NR<=1595 && /^def |^    def /{l=NR": "$0} END{}' "$MB/BaseTools/Source/Python/Common/Misc.py" >/dev/null
  grep -n "^def \|^    def " "$MB/BaseTools/Source/Python/Common/Misc.py" | awk -F: '$1<1595' | tail -3
  echo
  echo "== 用 BaseTools 自己的函数复现"
  cd "$MB/BaseTools/Source/Python" || exit 1
  PYTHONPATH="$MB/BaseTools/Source/Python" python3 - <<'PY'
import os, sys
sys.path.insert(0, os.getcwd())
from Common.Misc import GetRelativePath, PathConvert
try:
    from Common.BuildToolInvEnvironment import *
except Exception:
    pass
import Common.Misc as M
cand = [n for n in dir(M) if 'ase' in n or 'ath' in n]
print("helpers:", cand)
given = "MdePkg/MdeLibs.dsc.inc"
real  = "/home/unixnu/code/Mu_Basecore/MdePkg/MdeLibs.dsc.inc"
for n in ('ValidatePathCase','CheckFilePathCase','GetRealPath'):
    f = getattr(M, n, None)
    if f:
        try:
            print(n, "->", f(real if 'Real' not in n else given))
        except Exception as e:
            print(n, "EXC", type(e).__name__, e)
print("listdir Mu_Basecore Mde*:", [d for d in os.listdir('/home/unixnu/code/Mu_Basecore') if d.lower().startswith('mde')])
print("listdir uefi-umi-b M*:", [d for d in os.listdir('/home/unixnu/code/uefi-umi-b') if d.lower().startswith('m')])
print("workspace symlink?", os.path.islink('/home/unixnu/code/uefi-umi-b/Mu_Basecore'),
      os.path.realpath('/home/unixnu/code/uefi-umi-b/Mu_Basecore'))
PY
} > "$OUT" 2>&1
echo WROTE

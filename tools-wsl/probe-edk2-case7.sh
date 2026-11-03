#!/bin/bash
# 抓 RealPath2 源码 + 复现返回值
O=/mnt/e/Code/HackIos/out/edk2-case7.txt
PY=/home/unixnu/code/Mu_Basecore/BaseTools/Source/Python
{
echo "== grep RealPath2 / AlterRoot"
grep -n "RealPath2\|AlterRoot" $PY/Common/Misc.py | head -40
echo "== RealPath2 函数体（按缩进截）"
python3 - <<'PYEOF' 2>&1
import re
p="/home/unixnu/code/Mu_Basecore/BaseTools/Source/Python/Common/Misc.py"
t=open(p,encoding="utf-8",errors="replace").read().splitlines()
for i,l in enumerate(t):
    if re.match(r"\s*def RealPath2", l):
        ind=len(l)-len(l.lstrip())
        print("---- line",i+1)
        print(l)
        for j in range(i+1,len(t)):
            s=t[j]
            if s.strip() and (len(s)-len(s.lstrip()))<=ind: break
            print(s)
PYEOF
} > $O 2>&1
echo WROTE

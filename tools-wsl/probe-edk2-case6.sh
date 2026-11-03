#!/bin/bash
# 只读探底：edk2 RealPath2 / PathValidator 源码，以及它在本机的实际输入
O=/mnt/e/Code/HackIos/out/edk2-case6.txt
M=/home/unixnu/code/Mu_Basecore/BaseTools/Source/Python/Common/Misc.py
{
echo "== RealPath2 def 位置"
grep -n "def RealPath2\|class PathClass\|def Validate\|gCaseInsensitive" $M | head -20

echo "== RealPath2 全文"
S=$(grep -n "def RealPath2" $M | head -1 | cut -d: -f1)
sed -n "${S},$((S+45))p" $M

echo "== PathClass 定义头"
P=$(grep -n "class PathClass" $M | head -1 | cut -d: -f1)
sed -n "${P},$((P+40))p" $M

echo "== Validate 头 (1541..1556)"
sed -n '1541,1556p' $M

echo "== 谁调 Validate(Type='DSC')/ProcessDscFile 里的 include 解析"
grep -rn "Validate(" /home/unixnu/code/Mu_Basecore/BaseTools/Source/Python/Workspace/WorkspaceCommon.py /home/unixnu/code/Mu_Basecore/BaseTools/Source/Python/AutoGen/*.py 2>/dev/null | head -20

echo "== gCaseInsensitive 在哪设定"
grep -rn "gCaseInsensitive" /home/unixnu/code/Mu_Basecore/BaseTools/Source/Python/ | grep -v Binary | head -20
} > $O 2>&1
echo WROTE

#!/bin/bash
echo "=== all .adt under workspace out ==="
find /home/unixnu/code/umi-work-pin/out -name '*.adt' -printf '%TY-%Tm-%Td %TH:%TM:%TS %10s %p\n' 2>/dev/null | sort
echo "=== new kernel ==="
ls -la /home/unixnu/code/umi-work-pin/out/umi-xnu/umi/kernel/
echo "=== who writes .adt (unixnu tools) ==="
grep -rn "\.adt" /home/unixnu/code/umi-work-pin/sources/UniXNU/unixnu* 2>/dev/null | head -20
grep -rln "adt" /home/unixnu/code/umi-work-pin/sources/UniXNU/scripts 2>/dev/null | head -10

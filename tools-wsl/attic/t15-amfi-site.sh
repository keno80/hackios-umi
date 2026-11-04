#!/bin/bash
set -u
exec > /mnt/e/Code/HackIos/out/probes/t15-amfi-site.txt 2>&1
W=/home/unixnu/code/UniXNU-main/out/umi/tree/.cache/xnu-work

echo "== 1. accelerate_entitlement_queries 全文 =="
awk 'NR>=4340 && NR<=4470 {printf "%d\t%s\n", NR, $0}' $W/bsd/kern/ubc_subr.c

echo
echo "== 2. CODE_SIGNING_MONITOR 在本构建里的取值 =="
grep -rn "define CODE_SIGNING_MONITOR" $W 2>/dev/null | head -10
grep -rn "CODE_SIGNING_MONITOR" $W/bsd/kern/ubc_subr.c | head -5

echo
echo "== 3. amfi KPI 声明：OSEntitlements 成员与偏移顺序 =="
grep -rn "OSEntitlements" $W/bsd/kern/ubc_subr.c | head -10
F=$(grep -rl "adjustContextWithMonitor\|accelerateEntitlements" $W --include=*.h 2>/dev/null | head -3)
echo "头文件: $F"
for h in $F; do echo "-- $h --"; grep -n "accelerateEntitlements\|adjustContextWithMonitor\|struct .*OSEntitlements\|} OSEntitlements" "$h" | head -20; done

echo
echo "== 4. 现有 amfi-guard 补丁改了哪些文件 =="
grep -n "^--- \|^+++ " /mnt/e/Code/HackIos/patches/umi-xnu/zzzzzzzzzzzzzzzzzzz-umi-amfi-guard.patch

echo
echo "== 5. 内核重编入口 =="
ls /mnt/e/Code/HackIos/tools-wsl/ | grep -iE "^k[0-9]|build-kernel|rebuild|k-build" | head -20
grep -rln "source-kernel.macho" /mnt/e/Code/HackIos/tools-wsl/*.sh 2>/dev/null | head -20
echo "done $(date -u +%FT%TZ)"

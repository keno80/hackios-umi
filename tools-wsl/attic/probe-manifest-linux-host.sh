#!/bin/bash
# U 步之三备料取证：VerifiedRoot 的 manifest.py 到底吃什么、吐什么；上游有没有 Linux 侧的 host 编译通路。
exec > /mnt/e/Code/HackIos/out/probes/u94-manifest-and-linux-host.txt 2>&1
set -u
PIN=/home/unixnu/code/umi-work-pin
UP=$PIN/sources/UniXNU/kits/VerifiedRoot

echo "== A. kits/VerifiedRoot/tools/manifest.py 全文 =="
cat $UP/tools/manifest.py 2>&1

echo
echo "== B. src/verified_root.c 的对外符号与 include（Linux 可否直接编） =="
grep -n "^#include\|^vr_\|^int \|^void \|^const \|^struct " $UP/src/verified_root.c 2>&1 | head -50
echo "  -- include 目录 --"
ls -la $UP/include 2>&1
echo "  -- adapters --"
ls -la $UP/adapters 2>&1
cat $UP/tests/openssl_provider.c 2>&1 | head -60

echo
echo "== C. check.py 产物清单（哪些是 prepare 真正消费的） =="
grep -n "owner.pem\|owner-public\|verified-root\.\|report\[\|json.dump\|write_text" $UP/tests/check.py 2>&1

echo
echo "== D. 上游有没有 Linux 版的 host 编译/VerifiedRoot 通路 =="
grep -rln "VerifiedRoot" $PIN/tools /home/unixnu/code/UniXNU-main/scripts 2>/dev/null | head -30
echo "  -- 提到 openssl-prefix 的件 --"
grep -rn "openssl-prefix\|openssl_prefix" $PIN/tools $PIN/sources/UniXNU/kits/VerifiedRoot \
  /home/unixnu/code/UniXNU-main/scripts 2>/dev/null | head -20
echo "  -- 提到 -dynamiclib / dylib 的件 --"
grep -rn "dynamiclib\|\.dylib" $PIN/tools $PIN/sources/UniXNU/kits/VerifiedRoot \
  /home/unixnu/code/UniXNU-main/scripts 2>/dev/null | head -20
echo "  -- UniXNU-main/scripts/linux 里跟 root-policy 相关的 --"
ls -la /home/unixnu/code/UniXNU-main/scripts/linux 2>&1 | head -30
grep -rln "root-policy\|root_policy\|policies.json" /home/unixnu/code/UniXNU-main 2>/dev/null | head -20

echo
echo "== E. *-volume-info.json 的读者与写者（谁产它） =="
grep -rn "volume-info" $PIN/tools /home/unixnu/code/UniXNU-main/scripts /home/unixnu/code/UniXNU-main/bringup 2>/dev/null | head -20
echo "  -- 本仓 tools-wsl 里产 volume-info 的脚本 --"
grep -rln "volume-info" /mnt/e/Code/HackIos/tools-wsl 2>/dev/null | head -20
echo done

#!/bin/bash
# kit v3：AES-CBC/3DES-CBC/CTS/parity/SHA1 改绑真实现 → 重生成补丁 → 增量重编内核
set -u
O=/mnt/e/Code/HackIos/out/kit3-build.txt
exec > "$O" 2>&1
W=/home/unixnu/code/umi-work-pin
echo "== 先取 gss/ccrypto.c 的桩函数全表（重编会还原树）=="
grep -nE '^[a-z_0-9]+\(' "$W/out/umi-xnu/umi/tree/.cache/xnu-work/bsd/nfs/gss/ccrypto.c"
echo "== 重生成 crypto kit 补丁 =="
python3 /mnt/e/Code/HackIos/tools-wsl/make-crypto-patch.py
echo "make-crypto-patch rc=$?"
ls -l "$W/devices/umi/patches/umi-xnu/zzzzzzzzzzzzzzzzzz-umi-crypto-kit.patch"
echo "== 启动内核增量重编 =="
tr -d '\r' < /mnt/e/Code/HackIos/tools-wsl/run-kernel-screen.sh > /tmp/rks.sh
bash /tmp/rks.sh
sleep 20
LOGD=/home/unixnu/code/UniXNU-main/out/unixnu-logs
pid=$(cat "$LOGD/kernel-screen.pid")
echo "== pid=$pid alive? =="
kill -0 "$pid" 2>/dev/null && echo "RUNNING" || echo "NOT-RUNNING"
echo "LOG=$(cat "$LOGD/kernel-screen-latest.txt")"
tail -5 "$(cat "$LOGD/kernel-screen-latest.txt")"

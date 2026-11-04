#!/bin/bash
set -u
OUT=/mnt/e/Code/HackIos/out/probes/t23-rebind-kick.txt
: > "$OUT"; exec >>"$OUT" 2>&1
SRC=/mnt/e/Code/HackIos
R=/home/unixnu/code/umi-work-pin
T=$R/devices/umi

echo "== 1. 用仓库版覆盖 /usr/local/bin/ensure-dev-bind =="
tr -d '\r' < "$SRC/tools-wsl/ensure-dev-bind.sh" > /usr/local/bin/ensure-dev-bind
chmod +x /usr/local/bin/ensure-dev-bind
grep -n 'ls -A' /usr/local/bin/ensure-dev-bind || { echo "FAIL 守卫没进去"; exit 1; }

echo
echo "== 2. 重建 bind =="
ensure-dev-bind
echo "rc=$?"
findmnt -T "$T" 2>&1 | tail -2
ls "$T/board.toml" 2>&1

echo
echo "== 3. 起内核构建（30z） =="
bash "$SRC/tools-wsl/run-kernel-walk.sh"
echo
echo "== 4. 基线 sha 与日志 =="
sha256sum $R/out/umi-xnu/umi/kernel/source-kernel.macho
cat /home/unixnu/code/UniXNU-main/out/unixnu-logs/kernel-walk-latest.txt
echo "done $(date -u +%FT%TZ)"

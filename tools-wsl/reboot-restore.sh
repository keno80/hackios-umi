#!/bin/bash
# 重启后的现场恢复：装命令 -> 重建 devices/umi bind -> 起监控面板 -> 报状态。
# 加 --prune 顺带清掉 /usr/local/bin 里顶层已无同名脚本的陈旧快照（转给 sync-helpers）。
set -u
S=/mnt/e/Code/HackIos/tools-wsl
LOGD=/mnt/e/Code/HackIos/out/probes
PRUNE=${1:-}

echo "== 1. 装 /usr/local/bin 命令 =="
tr -d '\r' < "$S/sync-helpers.sh" > /tmp/sync-helpers.run && bash /tmp/sync-helpers.run $PRUNE

echo
echo "== 2. devices/umi bind =="
# ensure-dev-bind 装旧版会漏「非空目录」判定，把重启留下的空目录误判成需要停手，构建 kick 静默失败
ensure-dev-bind

echo
echo "== 3. 监控面板 8765 =="
bash "$S/launch-web.sh"
echo "  Windows 侧看 http://127.0.0.1:8765/"

echo
echo "== 4. 现场状态 =="
K=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/kernel/source-kernel.macho
[ -f "$K" ] && sha256sum "$K" || echo "  内核还没产出"
L=/home/unixnu/code/UniXNU-main/out/unixnu-logs/kernel-walk-latest.txt
[ -f "$L" ] && echo "  最近内核构建日志：$(cat "$L")"
for p in /home/unixnu/code/UniXNU-main/out/unixnu-logs/*.pid; do
  pid=$(cat "$p" 2>/dev/null)
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && echo "  在跑：$(basename "$p") pid=$pid"
done
ss -tln 2>/dev/null | grep -q 8765 && echo "  面板 OK" || echo "  面板没起来，见 $LOGD/web-launch.txt"
echo "done $(date -u +%FT%TZ)"

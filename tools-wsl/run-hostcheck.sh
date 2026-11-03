#!/bin/bash
# 组装 pin 工作区 + 跑 host 侧校验与单测（不需要定制 clang，可与工具链构建并行）
set -u
source /usr/local/bin/unixnu-env
CODE=/home/unixnu/code
WS=$CODE/umi-work
LOGD=$CODE/UniXNU-main/out/unixnu-logs
mkdir -p "$LOGD"
ts=$(date +%Y%m%d-%H%M%S)
LOG=$LOGD/hostcheck-$ts.log
echo "$LOG" > "$LOGD/hostcheck-latest.txt"
{
  echo "=== host check start $(date -Is) ==="
  if [ -d "$WS" ]; then
    echo "工作区已存在：$WS"
  else
    python3 "$CODE/UniXNU-umi/bringup/setup-workspace.py" --workspace "$WS" \
      --unixnu "$CODE/UniXNU" --uefi /mnt/e/Code/HackIos/uefi-umi --sheng "$CODE/UniXNU-sheng"
    echo "setup-workspace exit=$?"
  fi
  echo "=== 工作区布局 ==="
  ls -l "$WS" "$WS/sources" "$WS/devices" 2>/dev/null
  echo "=== check-umi-repository.py ==="
  cd "$WS" || exit 1
  python3 devices/umi/scripts/check-umi-repository.py --unixnu sources/UniXNU --out out/repository-check
  echo "repository-check exit=$?"
  echo "=== unittest 全量（tests/） ==="
  python3 -m unittest discover -s tests -v 2>&1 | tail -40
  echo "unittest-all exit=$?"
} > "$LOG" 2>&1
echo "LOG $LOG"
tail -30 "$LOG"

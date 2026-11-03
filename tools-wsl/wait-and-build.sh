#!/bin/bash
# 等工具链编完 -> 自检 -> 同时起 A/B 两条内核构建
set -u
LOGD=/home/unixnu/code/UniXNU-main/out/unixnu-logs
echo $$ > "$LOGD/wait.pid"
TLOG=$(cat "$LOGD/latest.txt")
TPID=$(cat "$LOGD/toolchain.pid" 2>/dev/null || true)
echo "等待工具链 pid=$TPID ..."
deadline=$(( $(date +%s) + 90 * 60 ))
while [ -n "$TPID" ] && kill -0 "$TPID" 2>/dev/null; do
  if [ "$(date +%s)" -gt "$deadline" ]; then echo "超时：工具链仍在运行"; exit 1; fi
  sleep 20
done
if grep -q 'toolchain ready in' "$TLOG"; then
  echo "工具链就绪：$(grep 'toolchain ready in' "$TLOG" | tail -1)"
else
  echo "工具链未成功结束，最后 30 行："
  tail -30 "$TLOG"
  exit 1
fi
for t in /opt/unixnu-linux/llvm/bin/clang /opt/unixnu-linux/CommandLineTools/usr/bin/ld \
         /opt/unixnu-linux/CommandLineTools/usr/bin/xnu-host-cc /opt/unixnu-linux/CommandLineTools/libexec/migcom \
         /opt/unixnu-linux/XcodeDefault.xctoolchain/usr/bin/iig /opt/unixnu-linux/bin/lzfse /usr/bin/xcrun; do
  [ -e "$t" ] && echo "OK  $t" || echo "缺失 $t"
done
echo "--- 启动 路B(main) 与 路A(pin 回移) ---"
/usr/local/bin/run-kernel-main
/usr/local/bin/run-kernel-pin
echo "工具链日志=$TLOG"

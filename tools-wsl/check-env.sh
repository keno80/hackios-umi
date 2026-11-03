#!/bin/sh
# 检查 UniXNU Linux 工具链所需的基础包是否落地
check() {
  if command -v "$1" >/dev/null 2>&1; then
    printf 'OK       %-16s %s\n' "$1" "$(command -v "$1")"
  else
    printf 'MISSING  %-16s\n' "$1"
  fi
}
for t in git make cmake ninja clang llvm-objcopy ld.lld dtc mtools unifdef iasl nasm pkg-config python3 pip3 rsync xz unzip file; do
  check "$t"
done
echo "--- apt/dpkg 状态 ---"
dpkg -l | grep -c '^ii' || true
if [ -f /var/lib/dpkg/lock-frontend ]; then
  fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 && echo "LOCKED: apt 仍在运行" || echo "LOCKED: 无进程占用（历史文件）"
fi
echo "--- 网络 ---"
curl -s -o /dev/null -w 'github raw: %{http_code}\n' --max-time 20 https://raw.githubusercontent.com/UniXNU/UniXNU/main/README.md || true
echo "proxy=$http_proxy"

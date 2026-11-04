#!/bin/bash
# 非破坏性自测 Windows 一键脚本：只跑「工具定位/设备枚举/镜像列表渲染/退出」。
# 绝不喂 [1]（adb reboot），选镜像时一律用空行取消，不触发 fastboot boot。
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
mkdir -p out/probes
OUT=out/probes/win-script-selftest.txt
: > "$OUT"
PS="$PWD/tools-win/fastboot-boot.ps1"

# run <标题> <工作目录> <喂给 Read-Host 的行, 用 ; 分隔, 空行=回车> [ps 参数...]
run() {
  local title="$1" cwd="$2" keys="$3"; shift 3
  {
    echo "==== $title ===="
    echo "---- cwd=$cwd  args=$*  keys=[$(echo "$keys" | tr '\n' '|')]"
    printf '%s\n' "$keys" | tr ';' '\n' | od -c | head -4
  } >> "$OUT" 2>&1
  ( cd "$cwd" && printf '%s\n' "$keys" | tr ';' '\n' | \
      powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$PS" "$@" 2>&1 ) >> "$OUT" 2>&1
  echo "rc=$?" >> "$OUT" 2>&1
}

echo "start $(date -Is)"
run "A 设备状态 + 退出（仓库根）"          "$PWD"           "3;4"
run "B 当前目录无 img -> 回落 + 列表渲染"   "$PWD/tools-win" "2;;4"
run "C 显式 -ImageDir"                     "$PWD"           "2;;4" -ImageDir "E:\\Code\\HackIos\\out\\images"
run "D 换目录 [d]"                          "$PWD"           "d;out/images;2;;4"
echo "end $(date -Is) lines=$(wc -l < "$OUT")"

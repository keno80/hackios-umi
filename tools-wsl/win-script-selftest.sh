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

# ---- 假 adb/fastboot：把「有设备」这条真机才会走的路径也覆盖掉 ----
# 上一版自测只跑了「没设备」的分支，$FB 被局部 $fb 顶掉的 bug 就是这么漏过去的。
SHIM="$PWD/out/probes/shim"
CSC="/c/Windows/Microsoft.NET/Framework64/v4.0.30319/csc.exe"
mkdir -p "$SHIM" "$PWD/out/probes/shimimg"
[ -s "$PWD/out/probes/shimimg/test-walk.img" ] || printf 'shim\n' > "$PWD/out/probes/shimimg/test-walk.img"
if [ -x "$CSC" ] || [ -f "$CSC" ]; then
  # csc.exe 只吃 Windows 路径，MSYS 路径递进去会被拆成 e:\Code\HackIos\dev-shim.cs 这种鬼样子
  { echo "==== 0. 编假件 ===="
    WSHIM=$(cygpath -w "$SHIM"); WCSRCS=$(cygpath -w "$PWD/tools-win/dev-shim.cs")
    "$CSC" -nologo -out:"${WSHIM}\\adb.exe" "$WCSRCS" 2>&1 | tail -2
    "$CSC" -nologo -out:"${WSHIM}\\fastboot.exe" "$WCSRCS" 2>&1 | tail -2
    ls -l "$SHIM"
  } >> "$OUT" 2>&1
else
  echo "==== 0. 没有 csc.exe，跳过假件（E 用例不跑）====" >> "$OUT"
fi

run "A 设备状态 + 退出（仓库根）"          "$PWD"           "3;4"
run "B 当前目录无 img -> 回落 + 列表渲染"   "$PWD/tools-win" "2;;4"
run "C 显式 -ImageDir"                     "$PWD"           "2;;4" -ImageDir "E:\\Code\\HackIos\\out\\images"
run "D 换目录 [d]"                          "$PWD"           "d;out/images;2;;4"
run "E 假设备走完整 boot 通路"              "$PWD"           "2;1;4" \
    -Tools "E:\\Code\\HackIos\\out\\probes\\shim" -ImageDir "E:\\Code\\HackIos\\out\\probes\\shimimg"

echo >> "$OUT"
echo "==== 断言 ====" >> "$OUT"
fail=0
if grep -qE "识别为 cmdlet|CommandNotFound" "$OUT"; then
  echo "[X] 输出里有 CommandNotFoundException：变量又被顶了" >> "$OUT"; fail=1
fi
grep -q "(shim fastboot) boot" "$OUT" || { echo "[X] 假 fastboot 没被调到：E 用例没走通" >> "$OUT"; fail=1; }
grep -q "\[OK\] fastboot: a7d186f4" "$OUT" || { echo "[X] boot 后没等到设备" >> "$OUT"; fail=1; }
grep -q "镜像目录：E:\\\\Code\\\\HackIos\\\\out\\\\probes\\\\shimimg" "$OUT" || \
  grep -q "shimimg" "$OUT" || { echo "[X] -ImageDir 后门没生效" >> "$OUT"; fail=1; }
[ "$fail" -eq 0 ] && echo "[OK] 全绿：含真机才会走的 boot 通路" >> "$OUT"
echo "end $(date -Is) lines=$(wc -l < "$OUT")"

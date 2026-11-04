#!/bin/bash
# 把 main 的 Linux 版助手脚本回移到 pin 树与 umi 设备仓（设备仓的 scripts 覆盖优先级更高）
set -u
MAIN=/home/unixnu/code/UniXNU-main
PIN=/home/unixnu/code/UniXNU-pin
UMI=/home/unixnu/code/UniXNU-umi
FILES="scripts/pbxproj.py scripts/kernel_target.py scripts/xnu_symbols.py scripts/build-corecrypto-14.py scripts/build-libpthread-kernel.py"
for f in $FILES; do
  for dst in "$PIN" "$UMI"; do
    [ -d "$dst/scripts" ] || continue
    base=$(basename "$f")
    [ "$dst" = "$PIN" ] && { [ "$base" = pbxproj.py ] || [ "$base" = kernel_target.py ] || [ "$base" = xnu_symbols.py ] || true; }
    if [ "$dst" = "$UMI" ] && [ "$base" != "build-corecrypto-14.py" ] && [ "$base" != "build-libpthread-kernel.py" ]; then
      continue
    fi
    t="$dst/scripts/$base"
    [ -f "$t" ] && [ ! -f "$t.macos-original" ] && cp -a "$t" "$t.macos-original"
    tr -d '\r' < "$MAIN/$f" > "$t"
    echo "写入 $t"
  done
done
echo "== 语法自检 =="
for d in "$PIN" "$UMI"; do
  for f in $d/scripts/pbxproj.py $d/scripts/kernel_target.py $d/scripts/xnu_symbols.py $d/scripts/build-corecrypto-14.py $d/scripts/build-libpthread-kernel.py; do
    [ -f "$f" ] || continue
    python3 -c "import ast,sys; ast.parse(open(sys.argv[1]).read())" "$f" && echo "OK   ${f#$d/}" || echo "语法错 $f"
  done
done
echo "== bootstrap 上一次的产物 =="
T=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree
ls -la "$T/build/xnu/ios-obj/DEVELOPMENT_ARM64_BCM2837/link.filelist" 2>/dev/null || echo "无 link.filelist"
find "$T/build/xnu/ios-obj/DEVELOPMENT_ARM64_BCM2837" -maxdepth 1 -name 'mach.development*' -printf '%s %p\n' 2>/dev/null | head -3
ls "$T/.cache/fakeroot/usr/local/lib/kernel/" 2>/dev/null

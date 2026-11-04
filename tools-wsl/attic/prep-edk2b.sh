#!/bin/bash
# 用 git 重新取 Mu_Basecore（cp -a 9P 副本丢了文件/元数据），并补齐嵌套 submodule
set -u
source /usr/local/bin/unixnu-env
D=/home/unixnu/code/Mu_Basecore
PIN=cfb93724a06ff86ff5ba971413368a7809ee42a5
if [ -d "$D" ]; then
  mv "$D" "${D}.bad.$(date +%s)"
  echo "旧副本已改名保留：$(ls -d ${D}.bad.* | tail -1)"
fi
echo "== clone mu_basecore (shallow)"
git clone --depth 1 --branch release/202608 https://github.com/microsoft/mu_basecore.git "$D" 2>&1 | tail -2
git -C "$D" fetch --depth 1 origin "$PIN" 2>&1 | tail -2
git -C "$D" checkout --quiet FETCH_HEAD 2>/dev/null || git -C "$D" checkout --quiet "$PIN"
echo "HEAD=$(git -C "$D" rev-parse HEAD) 期望=$PIN"
[ "$(git -C "$D" rev-parse HEAD)" = "$PIN" ] || { echo "HEAD 不是 pin，中止"; exit 1; }
echo "== 嵌套 submodule"
git -C "$D" submodule update --init --depth 1 \
  MdePkg/Library/BaseFdtLib/libfdt MdePkg/Library/MipiSysTLib/mipisyst \
  BaseTools/Source/C/BrotliCompress/brotli MdeModulePkg/Library/BrotliCustomDecompressLib/brotli \
  MdeModulePkg/Universal/RegularExpressionDxe/oniguruma 2>&1 | tail -6
for f in MdePkg/Library/BaseFdtLib/libfdt/libfdt/fdt.c \
         MdePkg/Library/MipiSysTLib/mipisyst/library/include \
         MdePkg/Include/X64/ProcessorBind.h \
         BaseTools/Source/C/BrotliCompress/brotli; do
  [ -e "$D/$f" ] && echo "OK   $f" || echo "缺失 $f"
done
echo "== BaseTools 宿主工具"
make -C "$D/BaseTools/Source/C" -j4 > /tmp/basetools.out 2>&1
echo "exit=$?"
[ -x "$D/BaseTools/Source/C/bin/GenFw" ] && echo "GenFw OK" || tail -12 /tmp/basetools.out

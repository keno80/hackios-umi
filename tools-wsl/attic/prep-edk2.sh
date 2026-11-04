#!/bin/bash
# Mu_Basecore 嵌套 submodule + BaseTools 宿主工具（GenFw/GenFv），为 QEMU 固件做准备
set -u
source /usr/local/bin/unixnu-env
D=/home/unixnu/code/Mu_Basecore
[ -d "$D" ] || { echo "还没有 ext4 副本，先跑 prep-qemu-fw"; exit 1; }
echo "HEAD=$(git -C "$D" rev-parse HEAD)"
for p in MdePkg/Library/BaseFdtLib/libfdt MdePkg/Library/MipiSysTLib/mipisyst \
         BaseTools/Source/C/BrotliCompress/brotli MdeModulePkg/Library/BrotliCustomDecompressLib/brotli \
         MdeModulePkg/Universal/RegularExpressionDxe/oniguruma; do
  if [ ! -d "$D/$p/.git" ] && [ ! -f "$D/$p/.git" ]; then
    echo "== submodule $p"
    git -C "$D" submodule update --init --depth 1 "$p" 2>&1 | tail -2
  fi
done
for f in MdePkg/Library/BaseFdtLib/libfdt/libfdt/fdt.c \
         MdePkg/Library/MipiSysTLib/mipisyst/library/include \
         BaseTools/Source/C/BrotliCompress/brotli; do
  [ -e "$D/$f" ] && echo "OK   $f" || echo "缺失 $f"
done
if [ ! -x "$D/BaseTools/Source/C/bin/GenFw" ]; then
  echo "== 构建 BaseTools C 工具（宿主 x86_64）"
  make -C "$D/BaseTools/Source/C" -j4 > /tmp/basetools.out 2>&1
  echo "exit=$? $(tail -3 /tmp/basetools.out | tr '\n' ' ')"
fi
ls "$D/BaseTools/Source/C/bin" 2>/dev/null | head -12 | tr '\n' ' '
echo

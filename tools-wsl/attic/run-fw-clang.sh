#!/bin/bash
# 组一个 edk2 CLANGPDB 能用的 CLANG_BIN（定制 clang + LLVM 工具），再试编 UniXNU 包
set -u
source /usr/local/bin/unixnu-env
B=/home/unixnu/code/clang-edk2
mkdir -p "$B"
ln -sf /opt/unixnu-linux/llvm/bin/clang "$B/clang"
ln -sf /opt/unixnu-linux/llvm/bin/clang++ "$B/clang++"
for t in llvm-ar llvm-objcopy llvm-nm llvm-strip llvm-dwarfp llvm-mc llvm-rc llvm-lib lld ld.lld; do
  src=$(command -v $t || ls /usr/lib/llvm-18/bin/$t 2>/dev/null)
  [ -n "${src:-}" ] && ln -sf "$src" "$B/$t" || echo "缺 $t"
done
ls "$B" | tr '\n' ' '; echo
"$B/clang" --version | head -2
FW=/home/unixnu/code/umi-work-pin/out/umi-qemu/firmware
export UNIXNU_EDK2=/home/unixnu/code/Mu_Basecore UNIXNU_BUILD_DIR=$FW JOBS=4 PYTHON_COMMAND=python3
export CLANG_BIN=$B/
cd /home/unixnu/code/UniXNU-main/package || exit 1
bash build.sh -b DEBUG -t CLANGPDB > "$FW/build-package-clang.log" 2>&1
echo "package(CLANGPDB) exit=$? 产物=$(ls "$FW/Build/Out/AARCH64-DEBUG/" 2>/dev/null | tr '\n' ' ')"
tail -15 "$FW/build-package-clang.log"

#!/bin/bash
# brew 的 Linux 入口对齐 shim（只做一件事：应答 --prefix <formula>）。
# 为什么需要：上游 display 档生成的 tree/build/native-legacy-display/build-from-sheng.py:157
#   llvm=Path(run(['brew','--prefix','llvm']).strip())/'bin'
# 然后拿 $(brew --prefix llvm)/bin/llvm-objcopy 去切 __mod_init_func + globalize 初始化工具符号。
# 本机没有 Homebrew，这条路直接 FileNotFoundError，把前面全部 ABI 断言（已过）一笔抹掉。
# 与 /opt/homebrew/opt/llvm/bin/llvm-objdump 那条 shim 同一个口径：只对齐入口，不改上游本体，
# 目录不在就明确报错，不拿空壳盖住真问题。
set -u
if [ "${1:-}" = "--prefix" ]; then
  if [ $# -eq 1 ]; then echo /opt/homebrew; exit 0; fi
  formula=$2
  p=/opt/homebrew/opt/$formula
  if [ -d "$p" ]; then echo "$p"; exit 0; fi
  echo "brew shim：本机没有 $formula 的对齐目录 $p（跑 sync-helpers.sh 装 llvm 那一组）" >&2
  exit 127
fi
echo "brew shim：本机只应答 --prefix [formula]，收到 $*" >&2
exit 127

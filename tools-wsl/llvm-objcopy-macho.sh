#!/bin/bash
# llvm-objcopy 的 Mach-O 入口 shim。
# 本机 Ubuntu LLVM 18.1.3 逐选项实测（out/probes/u204-objcopy-capability.txt）：
#   --remove-section 对 Mach-O 能用；--globalize-symbol / --keep-global-symbol 报
#   "option is not supported for MachO"。上游两处点名 --globalize-symbol：
#     devices/umi/scripts/build-umi-platform-power.py:131（UmiPlatformPower.late.o）
#     devices/umi/bringup/tools/build_umi_data_display.py:114/:118（NativeKeyStoreEvents / NativeGOPPresenter）
# 做法：其余参数原样交给真件跑完，再由 macho-globalize.py 把符号表那一行的 n_type 补上 N_EXT、
# 清掉 N_PEXT——这正是 --globalize-symbol 的语义，不碰上游任何脚本本体。
# 直通不盖真问题：没有 --globalize-symbol、认不出 input/output、输入不是小端 64 位 Mach-O，
# 全都直接 exec 真件（它自己的报错就是证据）。
set -u
REAL=${REAL_OBJCOPY:-/usr/bin/llvm-objcopy}
HELPER=${UMI_MACHO_GLOBALIZE:-/usr/local/lib/umi/macho-globalize.py}
[ -x "$REAL" ] || { echo "llvm-objcopy-macho: 找不到真件 $REAL" >&2; exit 1; }

globals=()
rest=()
while [ $# -gt 0 ]; do
  case "$1" in
    --globalize-symbol)
      [ $# -ge 2 ] || { echo "llvm-objcopy-macho: --globalize-symbol 缺参数" >&2; exit 1; }
      globals+=("$2"); shift 2 ;;
    --globalize-symbol=*)
      globals+=("${1#*=}"); shift ;;
    *)
      rest+=("$1"); shift ;;
  esac
done

if [ ${#globals[@]} -eq 0 ]; then
  exec "$REAL" "${rest[@]}"
fi
[ ${#rest[@]} -ge 2 ] || { echo "llvm-objcopy-macho: 认不出 input/output，交回真件" >&2; exec "$REAL" "${rest[@]}"; }
input=${rest[-2]}
output=${rest[-1]}
[ -f "$input" ] || { echo "llvm-objcopy-macho: 输入不是文件：$input，交回真件" >&2; exec "$REAL" "${rest[@]}"; }
magic=$(od -An -tx1 -N4 "$input" | tr -d ' \n')
if [ "$magic" != "cffaedfe" ]; then
  echo "llvm-objcopy-macho: 输入 magic=$magic 不是小端 64 位 Mach-O，交回真件" >&2
  exec "$REAL" "${rest[@]}"
fi
[ -f "$HELPER" ] || { echo "llvm-objcopy-macho: 缺 $HELPER（跑 sync-helpers.sh 装）" >&2; exit 1; }

"$REAL" "${rest[@]}" || exit $?
for g in "${globals[@]}"; do
  python3 "$HELPER" --input "$output" --symbol "$g" || exit $?
done

#!/bin/bash
# 装 /usr/local/bin 里的项目命令 + 补上游按 macOS Homebrew 位置点名的工具入口。
# 白名单是唯一出处——以前这里把顶层所有 *.sh 全量快照，
# 重启后 PATH 上会留一堆改名前的历史命令，指着早已搬走的脚本，这是「找不准入口」的根因。
# 加 --prune 才删除顶层已无同名 .sh 的陈旧快照。
set -u
S=/mnt/e/Code/HackIos/tools-wsl
PRUNE=${1:-}

# 白名单 = 顶层脚本实测按名字点名的那些（对照 out/probes/entry-pathcmds.txt）
# monitor_umi.py/launch-web.sh 另装 umi-mon.py、umi-web.py，不归这里管。
WL="unixnu-env ensure-dev-bind progress dashboard rawlog run-umi-qemu ab-status"

for f in $WL; do
  [ -f "$S/$f.sh" ] || { echo "跳过 $f：顶层没有 $f.sh"; continue; }
  tr -d '\r' < "$S/$f.sh" > "/usr/local/bin/$f" && chmod 755 "/usr/local/bin/$f" && echo "装 $f"
done

# 上游 Mac 路径 shim：设备树里的脚本按 Homebrew 位置直接点名工具，本机根本没有 /opt 那棵树。
# 只做「入口对齐」，不改任何校验脚本本体；目标二进制不在就明确报缺，不拿空壳盖住真问题。
#   llvm-objdump：devices/umi/scripts/build-boot-progress.py:53 与 :142 用它反汇编，
#     守「必须有 CNTPCT_EL0/CNTFRQ_EL0/DAIFSet/DAIF 这四条真指令、且不许出现 FP/SIMD 与翻译寄存器写」。
#     本机 Ubuntu LLVM 18.1.3 对这四条逐条 HIT（out/probes/u186-objdump-regex-check.txt），所以等价。
if [ -x /usr/bin/llvm-objdump ]; then
  mkdir -p /opt/homebrew/opt/llvm/bin
  ln -sfn /usr/bin/llvm-objdump /opt/homebrew/opt/llvm/bin/llvm-objdump \
    && echo "装 shim /opt/homebrew/opt/llvm/bin/llvm-objdump"
else
  echo "缺 shim：本机没有 /usr/bin/llvm-objdump，boot-progress 档会停在 objdump 调用"
fi

#   llvm-objcopy：Ubuntu LLVM 18.1.3 那份对 Mach-O 不实现 --globalize-symbol（u204 逐选项实测），
#     而 build-umi-platform-power.py:131 与 build_umi_data_display.py:114/:118 都点名它。
#     shim 装进 /usr/local/bin（PATH 里在 /usr/bin 前面，shutil.which 先命中它），
#     只补 Mach-O 的 globalize 这一步，ELF 与非 globalize 调用原样直通真件。
if [ -x /usr/bin/llvm-objcopy ] && [ -f "$S/macho-globalize.py" ]; then
  mkdir -p /usr/local/lib/umi
  tr -d '\r' < "$S/macho-globalize.py" > /usr/local/lib/umi/macho-globalize.py \
    && chmod 755 /usr/local/lib/umi/macho-globalize.py && echo "装 macho-globalize.py"
  tr -d '\r' < "$S/llvm-objcopy-macho.sh" > /usr/local/bin/llvm-objcopy \
    && chmod 755 /usr/local/bin/llvm-objcopy && echo "装 shim /usr/local/bin/llvm-objcopy"
else
  echo "缺 shim：llvm-objcopy 或 macho-globalize.py 不在位，platform-power / data-display 档会停在 objcopy 调用"
fi

if [ "$PRUNE" = "--prune" ]; then
  for c in /usr/local/bin/*; do
    b=$(basename "$c")
    [ -f "$c" ] || continue
    case " $WL umi-mon.py umi-web.py " in *" $b "*) continue ;; esac
    # 只删「以前全量同步装进来的那批」：顶层无同名 .sh，且是本项目形态的脚本
    [ -f "$S/$b.sh" ] && continue
    head -1 "$c" 2>/dev/null | grep -qE '^#!.*(ba)?sh' || continue
    case "$b" in adb|uefi-*|run-toolchain|run-fetch|run-hostcheck|wait-and-build) echo "留 $b（历史阶段/外部工具，不动）"; continue ;; esac
    case "$b" in llvm-objcopy) echo "留 $b（shim，白名单装件，不归陈旧快照）"; continue ;; esac
    rm -f "$c" && echo "删陈旧 $b"
  done
fi

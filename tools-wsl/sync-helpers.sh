#!/bin/bash
# 装 /usr/local/bin 里的项目命令。白名单是唯一出处——以前这里把顶层所有 *.sh 全量快照，
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

if [ "$PRUNE" = "--prune" ]; then
  for c in /usr/local/bin/*; do
    b=$(basename "$c")
    [ -f "$c" ] || continue
    case " $WL umi-mon.py umi-web.py " in *" $b "*) continue ;; esac
    # 只删「以前全量同步装进来的那批」：顶层无同名 .sh，且是本项目形态的脚本
    [ -f "$S/$b.sh" ] && continue
    head -1 "$c" 2>/dev/null | grep -qE '^#!.*(ba)?sh' || continue
    case "$b" in adb|uefi-*|run-toolchain|run-fetch|run-hostcheck|wait-and-build) echo "留 $b（历史阶段/外部工具，不动）"; continue ;; esac
    rm -f "$c" && echo "删陈旧 $b"
  done
fi

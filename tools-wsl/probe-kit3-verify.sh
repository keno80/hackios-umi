#!/bin/bash
# 等 kit v3 内核重编结束 → 静态验证（kit 不再取自 gss 桩）→ 起 QEMU run-12-kit3 + 打包 rev5
set -u
W=/home/unixnu/code/umi-work-pin
K=$W/out/umi-xnu/umi/tree/build/xnu/ios-obj/DEVELOPMENT_ARM64_BCM2837/mach.development.bcm2837.unstripped
SK=$W/out/umi-xnu/umi/kernel/source-kernel.macho
LOGD=/home/unixnu/code/UniXNU-main/out/unixnu-logs
OUT=/mnt/e/Code/HackIos/out/probes/kit3-verify.txt
NM=/usr/lib/llvm-18/bin/llvm-nm
OD=/usr/lib/llvm-18/bin/llvm-objdump

LOG=$(cat "$LOGD/kernel-screen-latest.txt")
PID=$(cat "$LOGD/kernel-screen.pid")
waited=0
while kill -0 "$PID" 2>/dev/null && [ "$waited" -lt 900 ]; do
  sleep 10
  waited=$((waited + 10))
done

{
  echo "== 等待=${waited}s  日志=$LOG"
  echo "== 构建日志尾部"
  tail -20 "$LOG"
  echo "== 构建产物"
  sha256sum "$SK" 2>&1 | cut -c1-64
  ls -l "$SK" 2>&1
  echo "== register 函数体调用的符号（去重）"
  A=$($NM --defined-only "$K" | awk '/_umi_crypto_kit_register$/{print $1}')
  START=0x$A
  END=$($NM -n --defined-only "$K" | awk -v s="$A" '$1>s{print "0x"$1; exit}')
  echo "range $START .. $END"
  $OD -d --start-address=$START --stop-address=$END "$K" 2>/dev/null > /tmp/reg.txt
  grep -oE '<_[a-z0-9_]+>' /tmp/reg.txt | sed 's/[<>]//g' | sort -u
  echo "== 仍引用 gss 桩？(期望 0)"
  grep -cE '<_ccaes_cbc_(en|de)crypt_mode>|<_ccdes3_cbc_|<_ccpad_cts3_|<_ccdes_key_set_odd_parity>|<_ccsha1_di>' /tmp/reg.txt
  echo "== 真实现引用 (期望 cc14_* 至少 4)"
  grep -oE 'cc14_[a-z0-9_]+' /tmp/reg.txt | sort | uniq -c
  echo "== ccaes_gladman_cbc_encrypt_mode 头 16 字节（首字段=ctx_size，须 <0x121）"
  GA=$($NM "$K" | awk '/_ccaes_gladman_cbc_encrypt_mode$/{print $1; exit}')
  $OD -s --start-address=0x$GA --stop-address=$(printf '0x%x' $((0x$GA + 16))) "$K" 2>/dev/null | tail -4
  echo "== ccsha1_ltc_di 头 48 字节"
  S1=$($NM "$K" | awk '/_ccsha1_ltc_di$/{print $1; exit}')
  $OD -s --start-address=0x$S1 --stop-address=$(printf '0x%x' $((0x$S1 + 48))) "$K" 2>/dev/null | tail -6
  echo "== 反汇编 umi_crypto_kit_register 前 40 条"
  head -48 /tmp/reg.txt | tail -40
} > "$OUT" 2>&1

cd /mnt/e/Code/HackIos || exit 1
setsid nohup bash tools-wsl/launch-qemu-screen.sh run-12-kit3 > out/kit3-qemu-launch.txt 2>&1 &
setsid nohup bash tools-wsl/run-pack-rev3.sh > out/kit3-pack-launch.txt 2>&1 &
sleep 20
{
  echo "== 20s 后子进程"
  pgrep -af 'run_umi_qemu|qemu-system-aarch64|build-xnu-payload|pack-menu-xnu' | head -6
  echo "== launch 输出"
  cat out/kit3-qemu-launch.txt out/kit3-pack-launch.txt
  echo "== run dir"
  ls -d $W/out/umi-qemu/run-12-kit3 2>&1
} >> "$OUT" 2>&1
echo done

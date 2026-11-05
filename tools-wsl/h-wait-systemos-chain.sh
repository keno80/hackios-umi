#!/bin/bash
# U 步之五：等 SystemOS 内核编完 → 验观测符号 → prelink → 三旗标 QEMU 取证 → 官方 analyze。
# 用法：h-wait-systemos-chain.sh
#   环境变量（都有默认值，跑老档不用改）：
#     TAG=systemos            构建日志/pid 基名，读 kernel-<TAG>-latest.txt / kernel-<TAG>.pid
#     PRELINK=qemu-systemos-union   prelink 输出名（同时喂给 run-systemos-qemu.sh 的 KERNEL）
#     RUN=39-systemos-union   QEMU 取证 run 名
#     REQUIRE_EXIT_RECORDS=0  置 1 时 _exit_records 不在内核里就停手（screen 档该置 1，
#                             否则白跑一趟 900 秒：官方 analyze 件第 59 行读不到址必然失败）
# 每一步失败都停手并把证据留在同一份日志里，别拿过期输入件往下跑。
set -u
TAG=${TAG:-systemos}
PRELINK=${PRELINK:-qemu-systemos-union}
RUN=${RUN:-39-systemos-union}
REQUIRE_EXIT_RECORDS=${REQUIRE_EXIT_RECORDS:-0}
exec > /mnt/e/Code/HackIos/out/probes/systemos-$TAG-chain.log 2>&1
WS=/home/unixnu/code/umi-work-pin
LOGD=/home/unixnu/code/UniXNU-main/out/unixnu-logs
TC=/opt/unixnu-linux
export PATH="$TC/CommandLineTools/usr/bin:$TC/bin:/usr/local/bin:/usr/bin:/bin"
export XNU_TOOLCHAIN_BIN="$TC/CommandLineTools/usr/bin $TC/XcodeDefault.xctoolchain/usr/bin"

L=$(cat $LOGD/kernel-$TAG-latest.txt)
PID=$(cat $LOGD/kernel-$TAG.pid 2>/dev/null || echo "")
echo "== 0. 档位：TAG=$TAG PRELINK=$PRELINK RUN=$RUN require_exit_records=$REQUIRE_EXIT_RECORDS"
echo "== 1. 等构建 pid=$PID 退出，日志 $L"
start=$(date +%s)
while [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; do
  sleep 30
  echo "[$(( $(date +%s) - start )) s] kernel.log $(wc -l < $(ls -1d $WS/out/umi-xnu/umi/logs/*/ | tail -1)/kernel.log 2>/dev/null) 行"
done
echo "== 构建结束，用时 $(( $(date +%s) - start )) s"
tail -25 "$L"

SRC=$WS/out/umi-xnu/umi/kernel/qemu-prelink-source-kernel.macho
echo
echo "== 2. 源内核新鲜度与观测符号是否真落地"
ls -l "$SRC" 2>&1
sha256sum "$SRC" 2>/dev/null | cut -c1-72
# 判符号一律用 cctools 那份 nm：本机 /opt/unixnu-linux/CommandLineTools/usr/bin/llvm-nm 不存在，
# 用它会静默返回空（2>/dev/null 吞掉 command not found），把「有」全判成「缺」。
NM=$TC/CommandLineTools/usr/bin/nm
[ -x "$NM" ] || { echo "停手：缺 $NM"; exit 1; }
"$NM" -n "$SRC" > /tmp/chain-nm.txt 2>/dev/null
echo "   nm 符号行数=$(wc -l < /tmp/chain-nm.txt)"
for s in _native_owner_cache_status _native_owner_cache_authorized \
         _native_owner_cache_native_union _native_owner_cache_dyld_flags \
         _initproc_spawned _umi_exec_trace_seen _umi_exec_trace_observation \
         _cs_native4k_full_blocks _cs_native4k_page_checks \
         _cs_native4k_ready_blobs; do
  n=$(grep -c " $s\$" /tmp/chain-nm.txt)
  printf '   %-40s %s\n' "$s" "$([ "$n" -ge 1 ] && echo 有 || echo '缺 <<<')"
done
# _exit_records 是 boot-progress 包（--gic-diagnostics --screen-diagnostics）里的 static，
# 官方 analyze 件第 59 行无条件读它 2382 字节。
NER=$(grep -c ' _exit_records$' /tmp/chain-nm.txt)
printf '   %-40s %s\n' "_exit_records" "$([ "$NER" -ge 1 ] && echo 有 || echo '无（本档未链 boot-progress）')"
[ "$REQUIRE_EXIT_RECORDS" = 1 ] && [ "$NER" = 0 ] && \
  { echo "停手：本档要求 _exit_records 在内核里，说明 boot-progress 没链进来——先看 kernel.log 的 build-boot-progress 段"; exit 1; }
MISS=$(for s in _native_owner_cache_status _native_owner_cache_authorized _native_owner_cache_native_union _initproc_spawned _umi_exec_trace_observation; do
  grep -c " $s\$" /tmp/chain-nm.txt
done | grep -c '^0$')
[ "$MISS" = 0 ] || { echo "停手：$MISS 个 SystemOS 观测符号不在内核里"; exit 1; }

echo
echo "== 3. prelink 出 $PRELINK"
tr -d '\r' < /mnt/e/Code/HackIos/tools-wsl/run-umi-prelink.sh > /tmp/run-umi-prelink.sh
rm -f $WS/out/umi-xnu/umi/kernel/$PRELINK.macho 2>/dev/null
cd "$WS" || exit 1
bash /tmp/run-umi-prelink.sh "$PRELINK"
K=$WS/out/umi-xnu/umi/kernel/$PRELINK.macho
[ -f "$K" ] || { echo "停手：prelink 没出 $K"; exit 1; }
sha256sum "$K" | cut -c1-72

echo
echo "== 4. 三旗标 QEMU 取证 $RUN（停 _panic，timeout 900）"
tr -d '\r' < /mnt/e/Code/HackIos/tools-wsl/run-systemos-qemu.sh > /tmp/run-systemos-qemu.sh
tr -d '\r' < /mnt/e/Code/HackIos/tools-wsl/run-umi-qemu.sh > /tmp/run-umi-qemu.sh 2>/dev/null || true
KERNEL=$WS/out/umi-xnu/umi/kernel/$PRELINK.macho bash /tmp/run-systemos-qemu.sh "$RUN" _panic

echo
echo "== 5. 官方 analyze_umi_systemos_qemu.py"
cd "$WS" || exit 1
rm -f out/umi-qemu/$RUN/analysis.json 2>/dev/null
python3 tools/analyze_umi_systemos_qemu.py out/umi-qemu/$RUN 2>&1
echo "analyze exit=$?"
echo "DONE"

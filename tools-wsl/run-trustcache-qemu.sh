#!/bin/bash
# U 步之四之二：trustcache-runtime 档在 QEMU 里跑到「launchd 的 AMFI 信任缓存查询」并取证
# 用法：run-trustcache-qemu [run 名，默认 38-trustcache-query] [停点符号，默认 _query_trust_cache]
# 前置：run-umi-prelink qemu-trustcache-runtime（出内核）+ run-original-trust-linux（出 bundle）
# 探路跑法：run-trustcache-qemu 38-trustcache-probe _panic  （FINISH=0 EXTRA_TRACE=1）
set -u
NAME=${1:-38-trustcache-query}
STOP=${2:-_query_trust_cache}
FINISH=${FINISH:-1}
EXTRA=${EXTRA_TRACE:-}
WS=/home/unixnu/code/umi-work-pin
TC=${UNIXNU_TOOLCHAIN:-/opt/unixnu-linux}
K=$WS/out/umi-xnu/umi/kernel/qemu-trustcache-runtime.macho
BUNDLE=$WS/out/umi/trustcache/original-static-system.bundle
LOG=/mnt/e/Code/HackIos/out/probes/trustcache-$NAME.log
exec > >(tee "$LOG") 2>&1

[ -f "$K" ] || { echo "缺 prelink 产物：$K"; exit 1; }
[ -f "$BUNDLE" ] || { echo "缺 bundle：先跑 run-original-trust-linux"; exit 1; }
echo "== 内核与 bundle"
sha256sum "$K" "$BUNDLE"

ARGS=(--root-volume --no-vmm-property --owned-memory-mib 320
      --trust-cache "$BUNDLE"
      --timeout 480 --capture-screen
      --args "-v keepsyms=1 kt_fixed_zones=120 offline-apfs-load=1"
      --trace _trust_cache_runtime_init --trace _load_init_program
      --read-symbol _trust_cache_static_init:1
      --read-symbol _trust_cache_static_loaded:1
      --read-symbol _trust_cache_rt_lock:16
      --read-symbol _umi_lock_failure_observation:512
      --read-symbol _umi_owner_root_observation:0x90)
[ "$FINISH" = 1 ] && ARGS+=(--stop "$STOP" --finish) || ARGS+=(--stop "$STOP")
if [ -n "$EXTRA" ]; then
  # 探路：把所有信任缓存/签名面候选都挂上 logpoint，从 lr 看谁是被 AMFI 调用的那一发
  for s in _query_trust_cache _check_trust_cache_runtime_for_uuid _load_trust_cache \
           _load_static_trust_cache _static_trust_cache_capabilities \
           _pmap_lookup_in_loaded_trust_caches _pmap_lookup_in_static_trust_cache \
           _match_compilation_service_cdhash _csproc_get_platform_binary \
           _csvnode_get_blob _csblob_get_cdhash _cs_require_lv _proc_getcdhash; do
    ARGS+=(--trace "$s")
  done
fi

tr -d '\r' < /mnt/e/Code/HackIos/tools-wsl/run-umi-qemu.sh > /tmp/run-umi-qemu.sh
cd "$WS" || exit 1
KERNEL=out/umi-xnu/umi/kernel/qemu-trustcache-runtime.macho \
  bash /tmp/run-umi-qemu.sh "$NAME" "${ARGS[@]}"
echo "run_umi_qemu exit=$?"

tr -d '\r' < /mnt/e/Code/HackIos/tools-wsl/evaluate-trustcache-evidence.py > /tmp/evtc.py
export PATH="$TC/CommandLineTools/usr/bin:$TC/bin:/usr/local/bin:/usr/bin:/bin"
export LC_ALL=C
python3 /tmp/evtc.py "$NAME"
echo "evaluate exit=$?"

#!/bin/bash
# U 步之一之二：等 prelink 输入档内核（stage=kernel, profile=qemu, crypto=prelinked）编完并验收
set -u
OUT=/mnt/e/Code/HackIos/out/probes/h-wait-prelink.txt
: > "$OUT"
exec >>"$OUT" 2>&1
LOGD=/home/unixnu/code/UniXNU-main/out/unixnu-logs
WS=/home/unixnu/code/umi-work-pin
L=$(cat $LOGD/kernel-prelink-latest.txt)
PID=$(cat $LOGD/kernel-prelink.pid 2>/dev/null || echo "")
ST=$WS/out/umi-xnu/umi/qemu-prelink-source-build-status.json
K=$WS/out/umi-xnu/umi/kernel/qemu-prelink-source-kernel.macho
export PATH=/opt/unixnu-linux/CommandLineTools/usr/bin:/opt/unixnu-linux/bin:$PATH

echo "等待 pid=$PID 结束  日志=$L"
start=$(date +%s)
while [ $(( $(date +%s) - start )) -lt 2700 ]; do
  if grep -q '"success": true' "$L" 2>/dev/null; then echo "命中结束标记 success=true"; break; fi
  if [ -n "$PID" ] && ! kill -0 "$PID" 2>/dev/null; then echo "pid 已退出（可能失败）"; break; fi
  sleep 30
  el=$(( $(date +%s) - start ))
  echo "[$el s] $(tail -1 "$L" 2>/dev/null | cut -c1-110)"
done
echo "== 用时 $(( $(date +%s) - start )) s =="

echo
echo "== 状态件 =="
python3 - <<EOF
import json,pathlib
p=pathlib.Path("$ST")
d=json.loads(p.read_text()) if p.exists() else {}
print('steps=',[(s['name'],s['exit_code']) for s in d.get('steps',[])])
for k in ('stage','profile','crypto_bootstrap','early_trace','success','prelinked','kernel','sha256','bytes'):
    print(f'{k}=',d.get(k))
EOF

echo
echo "== 产物 =="
ls -l "$K" 2>/dev/null && sha256sum "$K"

echo
echo "== 内核里必须同时在场：APFS 探针四全局 + corecrypto 符号（prelinked 档仍链 cc）=="
if [ -f "$K" ]; then
  xcrun nm -n "$K" > /tmp/prelink-nm.txt 2>/dev/null
  for s in _native_apfs_load_status _native_apfs_registered _native_apfs_vfsops \
           _native_apfs_probe_checkpoint _OSKextLoadKextWithIdentifier _vfs_fsadd \
           _umi_crypto_kit_register _ccrng _ccaes_ecb_encrypt_mode _cc14_ccdes3_cbc_encrypt_mode; do
    printf '%-34s %s\n' "$s" "$(grep -c -F " $s\$" /tmp/prelink-nm.txt)"
  done
  echo "cc* 总数=$(grep -c ' _cc' /tmp/prelink-nm.txt)"
  echo "-- 与 phone 基线的符号差（只看探针相关）--"
  xcrun nm -n $WS/out/umi-xnu/umi/kernel/source-kernel.macho 2>/dev/null | wc -l
  wc -l < /tmp/prelink-nm.txt
fi
echo
echo "== 失败时打日志尾 40 行 =="
grep -q '"success": true' "$L" 2>/dev/null || tail -40 "$L"
echo DONE

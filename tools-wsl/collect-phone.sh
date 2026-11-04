#!/bin/bash
# Task #9: read-only capture on the Mi 10 through the Windows adb server.
# No device writes: tools/collect_umi.py only reads props, procfs, GPT metadata
# and boot partitions, and copies them to the host.
set -u
ROOT_DIR=/home/unixnu/code/umi-work-pin
ADB_EXE=/mnt/e/platform-tools/adb.exe
LOG=/mnt/e/Code/HackIos/out/probes/collect-phone.txt
exec >"$LOG" 2>&1

if ! command -v adb >/dev/null 2>&1; then
  [ -f "$ADB_EXE" ] || { echo "adb.exe not found at $ADB_EXE"; exit 1; }
  printf '#!/bin/sh\nexec %s "$@"\n' "$ADB_EXE" >/usr/local/bin/adb
  chmod 755 /usr/local/bin/adb
  echo "installed /usr/local/bin/adb shim -> $ADB_EXE"
fi

echo "== adb version"; adb version | head -2
echo "== devices"
adb devices -l
mapfile -t SERIALS < <(adb devices | tail -n +2 | awk '$2=="device"{print $1}')
echo "device count: ${#SERIALS[@]}"
if [ "${#SERIALS[@]}" -eq 0 ]; then
  echo "STOP: 手机未连接或未授权（请插 USB、开 USB 调试、点“允许调试”）"
  exit 2
fi
if [ "${#SERIALS[@]}" -gt 1 ]; then
  echo "STOP: 多台设备，需人工指定 --serial：${SERIALS[*]}"
  exit 2
fi
SER=${SERIALS[0]}
echo "== serial: $SER"

echo "== identity (read only)"
for p in ro.product.device ro.board.platform ro.soc.model ro.build.version.release ro.lineage.version; do
  printf '%s=%s\n' "$p" "$(adb -s "$SER" shell getprop "$p" | tr -d '\r')"
done

echo "== root check (no settings changed)"
adb -s "$SER" root | tr -d '\r'
sleep 2
adb -s "$SER" wait-for-device
echo "id: $(adb -s "$SER" shell id | tr -d '\r')"
if ! adb -s "$SER" shell id | tr -d '\r' | grep -q 'uid=0'; then
  echo "STOP: ADB 不是 root（collector 硬要求 uid=0）。请确认 ROM 自带 adb root，或告知改用 su 逐条只读取数。"
  exit 3
fi

echo "== collect_umi.py"
cd "$ROOT_DIR" || { echo "no $ROOT_DIR"; exit 1; }
python3 tools/collect_umi.py --serial "$SER" "$@"
rc=$?
echo "collect_umi.py exit=$rc"
exit $rc

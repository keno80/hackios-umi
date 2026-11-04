set -u
OUT=/mnt/e/Code/HackIos/out/probes/m9-walk-qemu.txt
: > "$OUT"
exec >>"$OUT" 2>&1
WS=/home/unixnu/code/umi-work-pin
LOGD=/home/unixnu/code/UniXNU-main/out/unixnu-logs
NAME=run-21-walk
IMG=/mnt/e/Code/HackIos/out/fixtures/launchd-walk.macho
RUN=$WS/out/umi-qemu/$NAME
cd /mnt/e/Code/HackIos || exit 1
echo "== 0. 输入件 =="
sha256sum "$IMG"
echo
echo "== 1. 启动 QEMU（walk fixture + 读走查区）=="
if [ -e "$RUN" ]; then echo "（清掉上一轮 $RUN）"; rm -rf "$RUN"; fi
setsid nohup bash tools-wsl/run-umi-qemu.sh "$NAME" \
  --mockfs-initrd "$IMG" \
  --args "-v keepsyms=1 kt_fixed_zones=120" \
  --read-user-address 100004000:20 \
  --read-user-address 100004028:8 \
  --read-user-address 100004030:8 \
  --read-user-address 100004040:96 \
  --read-user-address 1000040c0:96 \
  --capture-screen --timeout 120 \
  > "$LOGD/qemu-$NAME.launch.log" 2>&1 &
echo "launcher pid=$!"
echo
echo "== 2. 等证据（screen.png 或 run-report/任意 json 出现，最多 900s）=="
for i in $(seq 1 180); do
  if [ -f "$RUN/screen.png" ] || ls "$RUN"/*.json >/dev/null 2>&1; then
    echo "EVIDENCE after $((i*5))s"; break
  fi
  sleep 5
done
echo
echo "== 3. run 目录 =="
ls -la "$RUN" 2>/dev/null | head -20
echo
echo "== 4. launch 日志尾 =="
tail -25 "$LOGD/qemu-$NAME.launch.log"
echo
echo "== 5. 走查区读回 =="
for f in "$RUN"/*.json; do
  [ -f "$f" ] || continue
  echo "-- $(basename "$f")"
  head -c 4000 "$f"
  echo
done
echo "== done $(date -u +%FT%TZ)"

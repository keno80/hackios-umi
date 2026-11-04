set -u
exec >>/mnt/e/Code/HackIos/out/probes/k12-merge-trace.txt 2>&1
DEV=/home/unixnu/code/UniXNU-umi
W=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi

echo "== 1. build_umi_xnu.py 位置 =="
find /home/unixnu/code -maxdepth 4 -name 'build_umi_xnu.py' 2>/dev/null

echo "== 2. 开关与互斥 =="
for F in $(find /home/unixnu/code -maxdepth 4 -name 'build_umi_xnu.py' 2>/dev/null); do
  echo "-- $F"
  grep -n "early.trace\|early_trace\|mockfs\|must not\|parser.error" "$F" | head -40
done

echo "== 3. patches/umi-xnu 目录 =="
ls -1 $DEV/patches/umi-xnu/ 2>/dev/null

echo "== 4. 产物内核早 trace 计数 =="
for k in $(find /home/unixnu/code/umi-work-pin/out -maxdepth 6 -name '*kernel.macho' 2>/dev/null); do
  printf "%s size=%s UMI_XNU=%s MOCKFS=%s INIT=%s\n" "$k" "$(stat -c%s "$k")" \
    "$(strings -a "$k" | grep -c 'UMI XNU')" \
    "$(strings -a "$k" | grep -c 'mockfs')" \
    "$(strings -a "$k" | grep -c 'INIT exec ok')"
done

echo "== 5. out/umi-xnu/umi/kernel 列表 =="
ls -la $W/kernel/ 2>/dev/null | head -20

echo "== 6. early-entry-trace 是否只吃 phone profile =="
for F in $(find /home/unixnu/code -maxdepth 4 -name 'run_umi_qemu.py' 2>/dev/null); do
  echo "-- $F"
  grep -n "umi_early_trace\|forbidden\|mockfs" "$F" | head -20
done
echo "== done =="

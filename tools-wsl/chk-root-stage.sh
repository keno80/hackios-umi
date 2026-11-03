#!/bin/bash
exec > /mnt/e/Code/HackIos/out/root-stage.txt 2>&1
echo "== whoami / bind restore =="
id
bash /home/unixnu/code/umi-work/tools/ensure-dev-bind.sh 2>&1 || \
  (cd /home/unixnu/code/umi-work-pin && bash tools/ensure-dev-bind.sh 2>&1)
echo "-- findmnt --"
findmnt -no SOURCE,TARGET --target /home/unixnu/code/umi-work-pin/devices/umi
ls /home/unixnu/code/umi-work-pin/devices/umi | head -20

echo "== tools present per tree =="
for d in umi-work umi-work-pin; do
  echo "--- $d ---"
  ls /home/unixnu/code/$d/tools 2>/dev/null | grep -E "prepare_umi_root|make_umi_payload|build_umi_xnu|run_umi_qemu"
done

echo "== ipsw-inputs.json (device repo) =="
head -c 2000 /home/unixnu/code/UniXNU-umi/ipsw-inputs.json
echo
echo "== device repo docs mention userdata/ipsw =="
grep -rln -E "prepare_umi_root|userdata" /home/unixnu/code/UniXNU-umi/docs /home/unixnu/code/UniXNU-umi/README*.md 2>/dev/null | head -20

echo "== cached ipsw anywhere =="
find /home/unixnu -maxdepth 5 -iname "*.ipsw" 2>/dev/null | head
find /home/unixnu/code/umi-work-pin/out -maxdepth 4 -type d 2>/dev/null | head -30

echo "== apple cdn reachable =="
curl -sI --max-time 25 "https://updates.cdn-apple.com/2025SpringFCS/fullrestores/122-77166/DCA6CFE8-90E9-4B92-880D-3DE171798E40/iPad_Pro_HFR_17.7.11_21H461_Restore.ipsw" | head -20

echo "== disk =="
df -h / /mnt/e | tail -3

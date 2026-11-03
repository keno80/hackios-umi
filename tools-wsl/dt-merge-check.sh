#!/bin/bash
set -u
cd /mnt/e/Code/HackIos/out/phone3/dt
out=/mnt/e/Code/HackIos/out/phone3-dt.txt

{
echo "=== 差异归因：fdtoverlay 产物 vs 运行中 live 树"
echo "尺寸: boot-dtb=$(stat -c %s boot-dtb.dtb) dtbo-8=$(stat -c %s dtbo-8.dtb) merged=$(stat -c %s merged.dtb) running=$(stat -c %s running.dtb)"
for f in merged running; do
  strip() { awk '/^\t__symbols__ \{/{s=1;next} s&&/^\t\};/{s=0;next} s{next} {print}' "$f.dts" | sed -e 's/^[ \t]*//' -e '/^$/d'; }
  strip > "$f.nosym"
  sort "$f.nosym" > "$f.sorted"
  echo "$f: 全文=$(wc -l < $f.dts) 行, 去符号=$(wc -l < $f.nosym) 行"
done

echo
echo "--- 顺序无关对比（sorted）"
diff -u merged.sorted running.sorted > /mnt/e/Code/HackIos/out/phone3-merge-sorted.diff
echo "rc=$? hunks=$(grep -c '^@@' /mnt/e/Code/HackIos/out/phone3-merge-sorted.diff) merged独有=$(grep -c '^-' /mnt/e/Code/HackIos/out/phone3-merge-sorted.diff) running独有=$(grep -c '^+' /mnt/e/Code/HackIos/out/phone3-merge-sorted.diff)"

echo
echo "--- 顺序相关对比（原序）"
diff -u merged.nosym running.nosym > /mnt/e/Code/HackIos/out/phone3-merge.diff
echo "rc=$? hunks=$(grep -c '^@@' /mnt/e/Code/HackIos/out/phone3-merge.diff)"
echo "结论：去符号后两边行数差 $(( $(wc -l < running.nosym) - $(wc -l < merged.nosym) ))，但原序 diff 有 $(grep -c '^@@' /mnt/e/Code/HackIos/out/phone3-merge.diff) 处 —— 差异主要是节点排列顺序。"

echo
echo "--- 真正的内容差异（排序后，逐条，最多 80 行）"
grep -E '^[-+]' /mnt/e/Code/HackIos/out/phone3-merge-sorted.diff | grep -v '^[-+][-+][-+]' | cut -c1-140 | head -80

echo
echo "--- 根节点对照"
for f in merged running; do
  echo "[$f] $(grep -m1 'model = ' $f.dts | cut -c1-70)"
  echo "     $(grep -m1 'qcom,board-id' $f.dts | cut -c1-50)"
  echo "     $(grep -m1 'compatible = ' $f.dts | cut -c1-70)"
done
echo
echo "--- chosen 节点对照"
for f in merged running; do
  echo "[$f]"
  awk '/^\tchosen \{/,/^\t\};/' "$f.dts" | sed -e 's/^[ \t]*//' | cut -c1-120
done
} > "$out" 2>&1
echo written

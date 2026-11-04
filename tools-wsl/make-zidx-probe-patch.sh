#!/bin/bash
# 落成 umi-zidx-probe 补丁（28z）：给 zalloc 的「页元数据 zidx 混淆」panic 加屏上判据。
# 依据（2026-11-04 真机 Q-WALK3 档屏上）：
#   `0xfffffff06720b000 expected in zone VM map entries[16], but metadata has invalid zidx: 64
#    @zalloc.c:777`，marks=24（极早期），同一份内核在 QEMU 里 23 发走查全绿、根本不进这条 panic。
# 上游 zalloc.c:775 这条 panic 只说「zidx 超出了 num_zones」，缺三件判读要的东西：
#   1) 当时 num_zones 到底多大（区分「还在建 zone 的早期窗口」还是「已经建完」）；
#   2) 在哪个 CPU 上（真机 8 核、QEMU 少核，SMP 竞态只有真机能暴露）；
#   3) 这条 meta 是元数据表里的第几槽、由哪个调用点检出（alloc 侧 zone_meta_validate
#      还是 free 侧 zone_invalid_element_panic——两者语义完全不同）。
# 姊妹 panic（787 行「found in 别的 zone」）一起加，免得真机换成那条又抓瞎。
set -uo pipefail
OUT=/mnt/e/Code/HackIos/out/probes/p-make-zidx-probe-patch.txt
: > "$OUT"
exec >> "$OUT" 2>&1

WS=/home/unixnu/code/umi-work-pin
X=$WS/out/umi-xnu/umi/tree/.cache/xnu-work
DEV=/home/unixnu/code/UniXNU-umi
ARCH=/mnt/e/Code/HackIos/patches/umi-xnu
REL=osfmk/kern/zalloc.c
Z=$X/$REL

echo "== 0. 名字：比现有最长的 z 补丁再多一个 z（保证重放顺序）=="
PREV=$(ls "$DEV/patches/umi-xnu/" | grep '^z' | awk '{n=index($0,"-")-1; if(n>m) m=n} END{print m}')
echo "当前最长 z 数=$PREV"
NAME=$(printf 'z%.0s' $(seq 1 $((PREV + 1))))-umi-zidx-probe.patch
echo "NAME=$NAME"
echo
echo "== 0b. 基线必须是干净的（没打过 28z）=="
if grep -q 'UMI28' "$Z"; then
  echo "-- 已存在 28z，先剥掉 --"
  ( cd "$X" && patch -R -p1 < "$DEV/patches/umi-xnu/$NAME" ) && echo "REVERSED-OK" \
    || { echo "REVERSE-FAIL"; exit 1; }
fi
echo
echo "== 0c. 编译前置：zone_info 必须在 panic 函数之前定义 =="
ZI=$(grep -n '^} zone_info;\|^static struct zone_info zone_info;\|^struct zone_info zone_info;' "$Z" | head -1)
echo "zone_info 定义行：$ZI"
ZN=$(printf '%s' "$ZI" | cut -d: -f1)
[ -n "$ZN" ] && [ "$ZN" -lt 761 ] || { echo "== 拒绝生成：zone_info 不在 761 行之前，(meta - zone_info.zi_meta_base) 编译不过"; exit 1; }
echo "cpu_number 在本文件已用=$(grep -c 'cpu_number()' "$Z")"
echo

echo "== 1. 生成 =="
WORK=$(mktemp -d)
mkdir -p "$WORK/a/osfmk/kern" "$WORK/b/osfmk/kern"
cp "$Z" "$WORK/a/osfmk/kern/"
cp "$Z" "$WORK/b/osfmk/kern/"

python3 - "$WORK" <<'PY'
import pathlib, sys

work = pathlib.Path(sys.argv[1])
rel = "osfmk/kern/zalloc.c"

edits = [
    # 1) 形参加一个检出点名：两个调用点语义不同，屏上必须能分清
    ("zone_page_metadata_index_confusion_panic(zone_t zone, vm_offset_t addr,\n"
     "    struct zone_page_metadata *meta)\n"
     "{",
     "zone_page_metadata_index_confusion_panic(zone_t zone, vm_offset_t addr,\n"
     "    struct zone_page_metadata *meta, const char *umi_zidx_site)\n"
     "{"),
    # 2) 主 panic：补 num_zones / cpu / 元数据槽号 / 检出点
    ("\t\tpanic(\"%p expected in zone %s%s[%d], but metadata has invalid zidx: %d\",\n"
     "\t\t    (void *)addr, zone_heap_name(zone), zone->z_name, zone_index(zone),\n"
     "\t\t    zidx);\n",
     "\t\tpanic(\"%p expected in zone %s%s[%d], but metadata has invalid zidx: %d\"\n"
     "\t\t    \" UMI28 nz=%d cpu=%d slot=%ld site=%s\",\n"
     "\t\t    (void *)addr, zone_heap_name(zone), zone->z_name, zone_index(zone),\n"
     "\t\t    zidx, (int)os_atomic_load(&num_zones, relaxed), cpu_number(),\n"
     "\t\t    (long)(meta - zone_info.zi_meta_base), umi_zidx_site);\n"),
    # 3) 姊妹 panic（zidx 合法但属于别的 zone）同样带上 nz/cpu/slot/site
    ("\tpanic(\"%p not in the expected zone %s%s[%d], but found in %s%s[%d]\",\n"
     "\t    (void *)addr, zone_heap_name(zone), zone->z_name, zone_index(zone),\n"
     "\t    zone_heap_name(src_zone), src_zone->z_name, zidx);\n",
     "\tpanic(\"%p not in the expected zone %s%s[%d], but found in %s%s[%d]\"\n"
     "\t    \" UMI28 nz=%d cpu=%d slot=%ld site=%s\",\n"
     "\t    (void *)addr, zone_heap_name(zone), zone->z_name, zone_index(zone),\n"
     "\t    zone_heap_name(src_zone), src_zone->z_name, zidx,\n"
     "\t    (int)os_atomic_load(&num_zones, relaxed), cpu_number(),\n"
     "\t    (long)(meta - zone_info.zi_meta_base), umi_zidx_site);\n"),
    # 4) alloc 侧调用点
    ("\t\tzone_page_metadata_index_confusion_panic(z, addr, meta);\n",
     "\t\tzone_page_metadata_index_confusion_panic(z, addr, meta, \"validate\");\n"),
    # 5) free 侧调用点
    ("\t\tzone_page_metadata_index_confusion_panic(zone, addr, meta);\n",
     "\t\tzone_page_metadata_index_confusion_panic(zone, addr, meta, \"free\");\n"),
]

p = work / "b" / rel
text = p.read_text()
for i, (old, new) in enumerate(edits):
    n = text.count(old)
    assert n == 1, (i, "anchor-count", n)
    text = text.replace(old, new)
p.write_text(text)
print("edited", rel, "edits=", len(edits))
PY
[ $? -eq 0 ] || { echo "EDIT-FAIL"; rm -rf "$WORK"; exit 1; }

echo
echo "== 2. diff =="
{
  echo "--- a/$REL"
  echo "+++ b/$REL"
  ( cd "$WORK" && diff -u "a/$REL" "b/$REL" ) | tail -n +3
} | tee "$WORK/body.diff"

echo
echo "== 3. 落盘 =="
cp "$WORK/body.diff" "$DEV/patches/umi-xnu/$NAME"
cp "$WORK/body.diff" "$ARCH/$NAME"
ls -la "$DEV/patches/umi-xnu/$NAME" "$ARCH/$NAME"
sha256sum "$DEV/patches/umi-xnu/$NAME" "$ARCH/$NAME"

echo
echo "== 4. 真实打回基线并核串 =="
( cd "$X" && patch -p1 < "$DEV/patches/umi-xnu/$NAME" ) && echo "APPLY-OK" || echo "APPLY-FAIL"
grep -n 'UMI28\|umi_zidx_site' "$Z"

echo
echo "== 5. CRLF 检查（补丁必须 LF）=="
for f in "$DEV/patches/umi-xnu/$NAME" "$ARCH/$NAME"; do
  printf '%s CR=%s\n' "$f" "$(tr -dc '\r' < "$f" | wc -c)"
done

echo
echo "== 6. 重放顺序 =="
ls "$DEV/patches/umi-xnu/" | grep '^z' | sort | tail -4
rm -rf "$WORK"
echo done

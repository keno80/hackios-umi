#!/bin/bash
# 接 s36：真 Apple EL0 件只能自己从 Cryptex1,SystemOS 裸容器里解。
# libfsapfs 20201107 断在 fs B-tree 根节点；本机已装 apfsprogs(0+git20231203)，先看它的工具面。
set -u
exec > /mnt/e/Code/HackIos/out/probes/s37-apfsprogs.txt 2>&1
IMG=/home/unixnu/code/umi-work-pin/out/umi-xnu/ipsw/21H461
CX=$IMG/044-76034-038.dmg

echo "== 1. apfsprogs 装了哪些可执行 =="
dpkg -L apfsprogs 2>/dev/null | grep -v '/man/'
echo "--- 相关包是否也在 ---"
for p in apfs-fuse hfsprogs libfsapfs-utils; do
  printf '%-16s %s\n' "$p" "$(dpkg-query -W -f='${Version}' "$p" 2>/dev/null || echo '-')"
done

echo
echo "== 2. dump-apfs 读 cryptex：容器/卷/元数据对象能不能走通 =="
timeout 120 dump-apfs "$CX" 2>&1 | head -60

echo
echo "== 3. 容器/incompat 特征与 APFS 版本（决定 2020 libfsapfs 为什么断）=="
python3 - "$CX" <<'PY'
import struct, sys
with open(sys.argv[1], 'rb') as f:
    for off in range(0, 64 * 1024 * 1024, 4096):
        f.seek(off)
        if f.read(8) == b'NXSB\0\0\0\0':
            f.seek(off); sb = f.read(256)
            (magic, vers, blocksize, num_blocks, next_id, ncid,
             csum_off, csum_type) = struct.unpack_from('<8Q', sb, 0)
            fmt, compat, incompat, ro_compat = struct.unpack_from('<4Q', sb, 0x50)
            uuid = sb[0xa0:0xb0]
            print(f'superblock @ {off:#x}  otool version={vers} blocks={num_blocks} '
                  f'next_catalog_id={next_id}')
            print(f'  features_map_format={fmt} compat={compat:#x} incompat={incompat:#x} ro_compat={ro_compat:#x}')
            print(f'  uuid={uuid.hex()}')
            # 文件系统 entry 起点
            n, = struct.unpack_from('<Q', sb, 0x70)
            print(f'  number_of_file_systems={n}')
            break
    else:
        print('  未在前 64MiB 找到 NXSB')
PY

echo
echo "== 4. apfsck 能不能过这个卷（过了就说明 2023 apfsprogs 认这代格式）=="
timeout 300 apfsck -n "$CX" 2>&1 | head -40

echo
echo "== 5. 备选：ipsw(Go) 发行件可达性——它自带 iOS17 APFS + LZFSE 解读者 =="
for base in https://api.github.com https://gh-proxy.com/https://api.github.com; do
  printf '%-46s ' "$base"
  timeout 25 curl -sS -o /tmp/ipswrel.json -w '%{http_code} %{size_download}B\n' \
    "$base/repos/blacktop/ipsw/releases/latest" 2>&1 | tr -d '\n'
  printf ' -> tag=%s\n' "$(python3 -c "import json;print(json.load(open('/tmp/ipswrel.json')).get('tag_name','?'))" 2>/dev/null || echo '?')"
done

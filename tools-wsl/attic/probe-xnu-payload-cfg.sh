#!/bin/bash
cd /home/unixnu/code/umi-work-pin || exit 1
echo "=== make_umi_payload.py 21-130 ==="
sed -n '21,130p' tools/make_umi_payload.py
echo
echo "=== unixnu-xnu.toml ==="
cat devices/umi/package/unixnu-xnu.toml 2>/dev/null | head -60

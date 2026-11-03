#!/bin/bash
set -u
WS=/home/unixnu/code/umi-work-pin
K=$WS/out/umi-xnu/umi/kernel/source-kernel.macho
X=$WS/out/umi-xnu/umi/tree/.cache/xnu-work
O=/mnt/e/Code/HackIos/out/cc-names.txt
{
  echo "== defined symbols cc(digest|sha|md5|hmac|rng) =="
  llvm-nm --defined-only "$K" 2>/dev/null | awk '{print $3}' | grep -E "^_cc(digest|sha|md5|hmac|rng)" | sort
  echo "== header prototypes =="
  grep -n "_di(void)" "$X/EXTERNAL_HEADERS/corecrypto/ccsha1.h" "$X/EXTERNAL_HEADERS/corecrypto/ccsha2.h" "$X/EXTERNAL_HEADERS/corecrypto/ccmd5.h" 2>/dev/null | head -12
  grep -n "ccdigest_final\|void ccdigest_init\|ccdigest_update" "$X/EXTERNAL_HEADERS/corecrypto/ccdigest.h" | head -10
  echo "== corecrypto dir listing =="
  ls "$X/osfmk/corecrypto" | head -40
} > "$O" 2>&1
echo done

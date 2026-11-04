#!/bin/bash
set -u
W=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
E=$W/EXTERNAL_HEADERS
O=/mnt/e/Code/HackIos/out/probes/cc-hdr-deps.txt
{
  for h in ccdigest.h cchmac.h ccsha1.h ccsha2.h ccaes.h ccdes.h ccmode.h ccrng.h; do
    echo "== $h includes =="
    grep -n '#include' "$E/corecrypto/$h" 2>/dev/null
    echo "   -- missing check --"
    for inc in $(grep -oE '#include <corecrypto/[^>]+>' "$E/corecrypto/$h" 2>/dev/null | sed -E 's#.*<corecrypto/##; s#>##'); do
      if [ -f "$E/corecrypto/$inc" ]; then echo "      OK   $inc"; else echo "      MISS $inc"; fi
    done
  done
  echo "== declarations we need =="
  grep -n 'ccdigest_init\|ccdigest_update\|void ccdigest' "$E/corecrypto/ccdigest.h" | head -20
  echo "-- final (inline?) --"
  grep -n 'ccdigest_final' "$E/corecrypto/ccdigest.h" | head -10
  echo "-- di accessors --"
  grep -n '_di(void)' "$E/corecrypto/ccsha1.h" "$E/corecrypto/ccsha2.h" | head -20
  echo "-- hmac api --"
  grep -n 'cchmac_init\|cchmac_update\|cchmac_final\|void[ ]*cchmac' "$E/corecrypto/cchmac.h" | head -20
  echo "-- aes mode externs --"
  grep -n 'ccaes_.*_mode' "$E/corecrypto/ccaes.h" | head -30
  echo "-- des mode externs --"
  grep -n 'cc\(t\)\?des_.*_mode' "$E/corecrypto/ccdes.h" | head -20
} > "$O" 2>&1
echo done

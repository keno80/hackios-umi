#!/bin/bash
set -u
OUT=/mnt/e/Code/HackIos/out/probes/macos-vm-prereq.txt
: > "$OUT"
say() { printf '%s\n' "$*" >> "$OUT"; }
S=/home/unixnu/code/UniXNU-main/scripts

say "== 1. Mac-only 脚本里的 arch/OS 断言 =="
for f in audit-storage-interface.py prepare-owner-data-fixture.py make-data-seed.py seed-data-grow.py audit-aes-interface.py build-virtio-mmio-bindings.py; do
  say "-- $f --"
  grep -nE 'uname|machine\.|platform\.|arm64|x86_64|[Dd]arwin|macosx|sys\.platform' "$S/$f" 2>/dev/null | head -10 >> "$OUT"
done

say
say "== 2. 这些脚本调用的外部工具 =="
grep -hoE "['\"(]\s*(xcrun|ditto|hdiutil|diskutil|ipsw|lipo|dwarfdump|codesign|plutil|mig|ld|clang)\b" \
  "$S"/audit-storage-interface.py "$S"/prepare-owner-data-fixture.py "$S"/make-data-seed.py \
  "$S"/seed-data-grow.py "$S"/audit-aes-interface.py "$S"/build-virtio-mmio-bindings.py 2>/dev/null | tr -d '("'\'' ' | sort | uniq -c >> "$OUT"

say
say "== 3. audit-storage-interface.py 的 macOS 专有用法上下文 =="
grep -n 'sdk macosx' -B 4 -A 8 "$S/audit-storage-interface.py" 2>/dev/null | head -30 >> "$OUT"
grep -n 'dwarfdump' -B 3 -A 10 "$S/audit-storage-interface.py" 2>/dev/null | head -40 >> "$OUT"

say
say "== 4. 审计脚本的输入/输出与硬钉 sha =="
grep -nE 'sha256|assert|raise SystemExit|f18b4df8|original_sha256|candidate' "$S/audit-storage-interface.py" 2>/dev/null | head -25 >> "$OUT"

say
say "== 5. make-data-seed.py 需要哪些 IPSW 成员（会不会撞上 AEA/iPadOS26）=="
grep -nE 'ipsw|DMG|dmg|Mount|mount|OS/|SystemOS|Cryptex|restore|Build|version' "$S/make-data-seed.py" 2>/dev/null | head -25 >> "$OUT"

say
say "== 6. seed-data-grow.py 是否也要 macOS =="
grep -nE 'hdiutil|diskutil|xcrun|apfs|resizeContainer|python' "$S/seed-data-grow.py" 2>/dev/null | head -15 >> "$OUT"
say done

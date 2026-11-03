#!/bin/bash
OUT=/mnt/e/Code/HackIos/out/menu-strings.txt
: > "$OUT"
P=/home/unixnu/code/umi-work-pin/out/umi-menu-package/UniXNUPkg
echo "== 屏幕字符串出处（整个 UniXNUPkg）" >> "$OUT"
grep -rn "no boot entry found\|built-in config\|Return to firmware\|Select an entry\|Vol +\|loaded / \|failed" "$P" --include="*.c" --include="*.h" 2>/dev/null | head -25 >> "$OUT"
echo "== drivers 计数是什么" >> "$OUT"
grep -rn "DriversLoaded\|DriverCount\|LoadedCount\|FailedCount\|mDrivers" "$P" --include="*.c" --include="*.h" 2>/dev/null | head -25 >> "$OUT"
echo "== 菜单条目来源（3 条 action）" >> "$OUT"
grep -rn "Restart\|Power off\|FirmwareAction\|Action\[" "$P" --include="*.c" 2>/dev/null | head -20 >> "$OUT"
echo "== 尾部那行被截断的 'ki' 可能是什么" >> "$OUT"
grep -rn "kip\|KernelCollection\|kit" "$P" --include="*.c" 2>/dev/null | head -12 >> "$OUT"
echo WROTE >> "$OUT"

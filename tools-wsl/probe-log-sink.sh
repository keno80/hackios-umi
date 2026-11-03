#!/bin/bash
W=/home/unixnu/code/umi-work-pin
D=/home/unixnu/code/uefi-umi-b
echo "== 1. connect_all / rotate 在菜单里是什么"
grep -rn -E "connect_all|rotate|timeout" "$W/out/umi-menu-package/UniXNUPkg" 2>/dev/null | head -12 | sed 's#^#  #'
echo "== 2. 固件里有没有 USB 串口/CDC 调试通道"
grep -rln -E "CdcAcm|UsbSerialDebug|DebugLogPort|EfiDebugLogProtocol" "$D/Silicon" 2>/dev/null | head -10 | sed 's#^#  #'
echo "== 3. 现有 DXE 列表里的串口/调试模块"
grep -n -i -E "serial|debug|uart" "$D/Platforms/Xiaomi/umiPkg/Include/DXE.inc" | sed 's#^#  #'
echo "== 4. 顶层 PcdDebugPrintErrorLevel / DebugFifo 之类"
grep -rn -E "PcdDebugPrintErrorLevel|DebugPerformanceManager|PcdSerial.*Enable" "$D/Platforms/Xiaomi/umiPkg/umi.dsc" "$D/Silicon/Silicium/SiliciumPkg/SiliciumPkg.dsc.inc" 2>/dev/null | head -10 | sed 's#^#  #'
echo "== 5. 串口设备基址（真机要接线的口）"
grep -rn -i -E "UART_BASE|DebugSerialPort|PcdSerialPortBase|MSM_UART" "$D/Silicon" 2>/dev/null | head -10 | sed 's#^#  #'

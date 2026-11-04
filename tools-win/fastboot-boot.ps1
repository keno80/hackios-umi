#Requires -Version 5.1
<#
    umi 一键上机（Windows）

    [1] adb reboot bootloader —— 一键把手机重启进 fastboot
    [2] 选当前目录下的 .img → fastboot boot（零写入，不动任何分区）
        启动后最多等 60 秒；期间没冒出一个 fastboot/adb 设备就自动回开始页
    [3] 看当前设备状态
    [d] 换镜像目录

    工具与镜像目录都是自动探测：优先 E:\Android\SDK\platform-tools，
    镜像优先当前目录，没有就用 C:\Users\admin\Desktop\phone-capture。
#>
param([string]$ImageDir = '')

$ErrorActionPreference = 'Continue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

# ---------- 工具定位 ----------
$ToolCandidates = @('E:\Android\SDK\platform-tools', 'E:\platform-tools', 'D:\platform-tools',
                    "$env:LOCALAPPDATA\Android\Sdk\platform-tools")
$ToolDir = ''
foreach ($c in $ToolCandidates) {
    if ($c -and (Test-Path (Join-Path $c 'fastboot.exe'))) { $ToolDir = $c; break }
}
if (-not $ToolDir) {
    $g = Get-Command fastboot.exe -ErrorAction SilentlyContinue
    if ($g) { $ToolDir = Split-Path $g.Source -Parent }
}
if (-not $ToolDir) {
    Write-Host '[X] 没找到 fastboot.exe（platform-tools）。装好后重跑，或改脚本顶部 $ToolCandidates。' -ForegroundColor Red
    exit 1
}
$ADB = Join-Path $ToolDir 'adb.exe'
$FB  = Join-Path $ToolDir 'fastboot.exe'

# ---------- 设备枚举 ----------
function Get-AdbList {
    $r = @()
    if (-not (Test-Path $ADB)) { return ,$r }
    foreach ($line in (& $ADB devices 2>$null)) {
        $t = ('' + $line).Trim()
        if (-not $t) { continue }
        if ($t -like 'List of devices*' -or $t.StartsWith('*')) { continue }
        $p = $t -split '\s+'
        if ($p.Count -ge 2) { $r += [pscustomobject]@{ Serial = $p[0]; State = $p[1] } }
    }
    return ,$r
}

function Get-FastbootList {
    $r = @()
    foreach ($line in (& $FB devices 2>$null)) {
        $t = ('' + $line).Trim()
        if (-not $t) { continue }
        $r += (($t -split '\s+')[0])
    }
    return ,$r
}

function Wait-AnyDevice([int]$Seconds) {
    $end = (Get-Date).AddSeconds($Seconds)
    while ((Get-Date) -lt $end) {
        $fb = Get-FastbootList
        if ($fb.Count -gt 0) { return ("fastboot: " + ($fb -join ', ')) }
        $ad = @(Get-AdbList | Where-Object { $_.State -ne 'offline' })
        if ($ad.Count -gt 0) {
            $s = ($ad | ForEach-Object { "$($_.Serial)($($_.State))" }) -join ', '
            return ("adb: " + $s)
        }
        Start-Sleep -Milliseconds 800
    }
    return $null
}

function Show-Devices {
    $fb = Get-FastbootList
    $ad = Get-AdbList
    if ($fb.Count -gt 0) { Write-Host ("  fastboot  : " + ($fb -join ', ')) -ForegroundColor Green }
    else { Write-Host '  fastboot  : （无）' }
    if ($ad.Count -gt 0) {
        foreach ($d in $ad) { Write-Host ("  adb       : {0}  {1}" -f $d.Serial, $d.State) -ForegroundColor Green }
    } else { Write-Host '  adb       : （无）' }
}

# ---------- 镜像目录与选择 ----------
function Find-Images([string]$Dir) {
    if (-not $Dir -or -not (Test-Path $Dir)) { return @() }
    return @(Get-ChildItem -LiteralPath $Dir -Filter *.img -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending)
}

function Normalize-ImageDir([string]$Dir) {
    $fallbacks = @("$env:USERPROFILE\Desktop\phone-capture",
                   'C:\Users\admin\Desktop\phone-capture',
                   (Join-Path $PSScriptRoot '..\out\images'))
    $d = $Dir
    if (-not $d -or -not (Test-Path $d)) { $d = (Get-Location).Path }
    if ((Find-Images $d).Count -gt 0) { return (Resolve-Path $d).Path }
    foreach ($alt in $fallbacks) {
        if (-not $alt -or -not (Test-Path $alt)) { continue }
        if ((Find-Images $alt).Count -gt 0) {
            Write-Host ("[i] {0} 下没有 .img，改用 {1}" -f (Resolve-Path $d).Path, (Resolve-Path $alt).Path) -ForegroundColor DarkGray
            return (Resolve-Path $alt).Path
        }
    }
    return (Resolve-Path $d).Path
}

function Pick-Image {
    $imgs = Find-Images $script:ImgDir
    Write-Host ''
    Write-Host ("  镜像目录：{0}" -f $script:ImgDir) -ForegroundColor Cyan
    if ($imgs.Count -eq 0) {
        Write-Host '  这个目录下没有 .img。按 [d] 换一个目录，或下面直接填完整路径。' -ForegroundColor Yellow
    } else {
        $i = 0
        foreach ($f in $imgs) {
            $i++
            Write-Host ("  [{0}] {1,-40} {2,8:N1} MiB  {3:MM-dd HH:mm}" -f `
                $i, $f.Name, ($f.Length / 1MB), $f.LastWriteTime)
        }
    }
    $ans = Read-Host '  序号 / 镜像路径 / 回车取消'
    if (-not $ans) { return $null }
    $n = 0
    if ([int]::TryParse($ans.Trim(), [ref]$n)) {
        if ($n -ge 1 -and $n -le $imgs.Count) { return $imgs[$n - 1].FullName }
        Write-Host '  序号不在范围内' -ForegroundColor Yellow
        return $null
    }
    $p = $ans.Trim().Trim('"')
    if (-not [System.IO.Path]::IsPathRooted($p)) { $p = Join-Path (Get-Location).Path $p }
    if (Test-Path -LiteralPath $p -PathType Leaf) { return (Resolve-Path -LiteralPath $p).Path }
    Write-Host "  文件不存在：$p" -ForegroundColor Yellow
    return $null
}

# ---------- 动作 ----------
function Do-RebootToBootloader {
    $ad = @(Get-AdbList | Where-Object { $_.State -eq 'device' })
    if ($ad.Count -eq 0) {
        Write-Host '[X] 没有在线的 adb 设备，发不了 reboot bootloader。' -ForegroundColor Yellow
        Write-Host '    手机已经 in fastboot 就直接选 [2]；' 
        Write-Host '    否则关机后长按 音量下 + 电源 进 fastboot，再选 [2]。'
        return
    }
    $serial = $ad[0].Serial
    if ($ad.Count -gt 1) {
        Write-Host '  多台 adb 设备：'
        for ($i = 0; $i -lt $ad.Count; $i++) { Write-Host ("   [{0}] {1}" -f ($i + 1), $ad[$i].Serial) }
        $t = Read-Host '  选哪台（回车=第一台）'
        $n = 1
        if ($t -and [int]::TryParse($t.Trim(), [ref]$n)) { }
        else { Write-Host '  无效序号，用第一台' -ForegroundColor DarkGray }
        if ($n -ge 1 -and $n -le $ad.Count) { $serial = $ad[$n - 1].Serial }
    }
    Write-Host ("[>] adb -s {0} reboot bootloader" -f $serial)
    & $ADB -s $serial reboot bootloader 2>&1 | ForEach-Object { Write-Host ("    " + $_) }
    $hit = Wait-AnyDevice 60
    if ($hit) { Write-Host ("[OK] " + $hit) -ForegroundColor Green }
    else { Write-Host '[!] 1 分钟内没发现 fastboot/adb 设备，回开始页' -ForegroundColor Yellow }
}

function Do-Boot([string]$Img) {
    $fb = Get-FastbootList
    if ($fb.Count -eq 0) {
        Write-Host '[X] 现在没有 fastboot 设备，boot 发不出去。先选 [1]（或手动进 fastboot）。' -ForegroundColor Yellow
        return
    }
    Write-Host ("[>] fastboot boot `"{0}`"   （零写入）" -f $Img)
    & $FB boot $Img 2>&1 | ForEach-Object { Write-Host ("    " + $_) }
    $hit = Wait-AnyDevice 60
    if ($hit) { Write-Host ("[OK] " + $hit) -ForegroundColor Green }
    else { Write-Host '[!] 1 分钟内没发现 fastboot/adb 设备，回开始页' -ForegroundColor Yellow }
}

# ---------- 主菜单 ----------
$script:ImgDir = Normalize-ImageDir $ImageDir
while ($true) {
    Write-Host ''
    Write-Host '=================== umi 一键上机 ===================' -ForegroundColor Cyan
    Write-Host '  [1] 重启到 fastboot（adb reboot bootloader）'
    Write-Host '  [2] 选镜像 → fastboot boot（零写入；1 分钟无设备自动回本页）'
    Write-Host '  [3] 看当前设备状态'
    Write-Host '  [d] 换镜像目录'
    Write-Host '  [4] 退出'
    Write-Host ("  工具：{0}" -f $ToolDir)
    Write-Host ("  镜像目录：{0}" -f $script:ImgDir)
    $key = (Read-Host '  选').Trim().ToLower()
    switch ($key) {
        '1' { Do-RebootToBootloader }
        '2' { $p = Pick-Image; if ($p) { Do-Boot $p } }
        '3' { Show-Devices }
        'd' {
            $t = Read-Host '  新目录（回车取消）'
            if ($t) {
                $t = $t.Trim().Trim('"')
                if (-not [System.IO.Path]::IsPathRooted($t)) { $t = Join-Path (Get-Location).Path $t }
                if (Test-Path -LiteralPath $t -PathType Container) { $script:ImgDir = (Resolve-Path -LiteralPath $t).Path }
                else { Write-Host "  目录不存在：$t" -ForegroundColor Yellow }
            }
        }
        '4' { return }
        default { Write-Host '  没这个选项' -ForegroundColor Yellow }
    }
}

$P = 'E:\Code\HackIos'
Write-Output "=== pstore-list.txt ==="
Get-Content "$P\phone-capture\pstore-list.txt" -ErrorAction SilentlyContinue | Select-Object -First 10
Write-Output "=== pstore console 前 6 行 ==="
Get-Content "$P\phone-capture\pstore-console-ramoops-0.txt" -TotalCount 6 -ErrorAction SilentlyContinue

$ErrorActionPreference = 'Stop'

$log = 'C:\data\winSmallCoordinator\logs\diagnostic.log'
$whitelistFile = Join-Path $PSScriptRoot 'process-whitelist.txt'
$leftovers = 'C:\marco_leftovers'
New-Item -ItemType Directory -Force -Path (Split-Path $log) | Out-Null
$lines = New-Object System.Collections.Generic.List[string]
function Log($msg) { $lines.Add("[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] $msg") }

$limits = @{}
Get-Content $whitelistFile | ForEach-Object { $_.Trim() } | Where-Object { $_ -and -not $_.StartsWith('#') } | ForEach-Object {
  if ($_ -match '^(.*\S)\s+(\d+)$') { $limits[$Matches[1]] = [int]$Matches[2] } else { $limits[$_] = [double]::PositiveInfinity }
}
$killed = 0
foreach ($p in Get-CimInstance Win32_Process) {
  if ($p.ProcessId -le 4 -or $p.ProcessId -eq $PID -or -not $p.CreationDate) { continue }
  $minutes = $limits[[IO.Path]::GetFileNameWithoutExtension($p.Name)]
  if (-not $minutes) { $minutes = 60 }
  if (((Get-Date) - $p.CreationDate).TotalMinutes -lt $minutes) { continue }
  try { Stop-Process -Id $p.ProcessId -Force; Log "killed $($p.Name) (pid $($p.ProcessId)): $($p.CommandLine)" }
  catch { Log "ATTENTION: could not kill $($p.Name) (pid $($p.ProcessId)): $($_.Exception.Message)" }
  $killed++
}
if ($killed -eq 0) { Log "process sweep: clean" }

# A file the OS still has open simply fails to delete, so live build output
# needs no special case here.
$cutoff = (Get-Date).AddDays(-7)
$freed = 0
$stale = @(Get-ChildItem "$HOME\.local\bin" -Filter 'claude.exe.old.*' -ErrorAction SilentlyContinue) + @(Get-ChildItem $env:TEMP, 'C:\Windows\Temp', "$HOME\.local\share\claude\versions" -Force -ErrorAction SilentlyContinue)
foreach ($item in $stale) {
  if ($item.LastWriteTime -ge $cutoff) { continue }
  $path = "\\?\$($item.FullName)"
  if ($item.PSIsContainer -and (Get-ChildItem -LiteralPath $path -Recurse -Force -ErrorAction SilentlyContinue | Where-Object LastWriteTime -ge $cutoff | Select-Object -First 1)) { continue }
  $size = if ($item.PSIsContainer) { (Get-ChildItem -LiteralPath $path -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum } else { $item.Length }
  Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction SilentlyContinue
  if (-not (Test-Path -LiteralPath $path)) { $freed += $size }
}
Clear-RecycleBin -DriveLetter C -Force -ErrorAction SilentlyContinue
Log "freed $([math]::Round($freed/1MB,1)) MB"

foreach ($item in Get-ChildItem "$HOME\Downloads" -Force -ErrorAction SilentlyContinue) {
  if ($item.LastWriteTime -ge $cutoff -or $item.Name -eq 'desktop.ini') { continue }
  Move-Item $item.FullName (Join-Path $leftovers $item.Name) -Force -ErrorAction SilentlyContinue
  Log "moved $($item.Name) into marco_leftovers"
}

$freeGB = [math]::Round((Get-PSDrive C).Free / 1GB, 1)
Log "disk free: ${freeGB}GB"
if ($freeGB -lt 20) { Log "ATTENTION: low disk space" }
$agents = (Get-Process claude -ErrorAction SilentlyContinue | Measure-Object).Count
if ($agents -lt 4) { Log "ATTENTION: only $agents claude.exe running, expected 4" }

Add-Content -Path $log -Value $lines -Encoding utf8
$all = @(Get-Content $log)
if ($all.Count -gt 8000) { $all | Select-Object -Last 4000 | Set-Content -Path $log -Encoding utf8 }

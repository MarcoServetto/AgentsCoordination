$ErrorActionPreference = 'Stop'

$log = 'C:\data\winCoordinator\logs\diagnostic.log'
$whitelistFile = 'C:\data\winCoordinator\scripts\process-whitelist.txt'
$leftovers = 'C:\Users\sonta\Desktop\MarcoLeftovers'
$lines = New-Object System.Collections.Generic.List[string]
function Log($msg) { $lines.Add("[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] $msg") }

$whitelist = Get-Content $whitelistFile | Where-Object { $_.Trim() -and -not $_.Trim().StartsWith('#') } | ForEach-Object { $_.Trim().ToLowerInvariant() }
$killed = 0
foreach ($p in Get-CimInstance Win32_Process) {
  if ($p.ProcessId -le 4 -or -not $p.CreationDate) { continue }
  if ($whitelist -contains [IO.Path]::GetFileNameWithoutExtension($p.Name).ToLowerInvariant()) { continue }
  if (((Get-Date) - $p.CreationDate).TotalHours -lt 1) { continue }
  Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
  Log "killed $($p.Name) (pid $($p.ProcessId)): $($p.CommandLine)"
  $killed++
}
if ($killed -eq 0) { Log "process sweep: clean" }

# A file the OS still has open simply fails to delete, so the running claude.exe
# and any live build output need no special case here.
$cutoff = (Get-Date).AddDays(-7)
$freed = 0
foreach ($dir in $env:TEMP, 'C:\Windows\Temp', "$HOME\.local\bin", "$HOME\.local\share\claude\versions") {
  foreach ($item in Get-ChildItem $dir -Force -ErrorAction SilentlyContinue) {
    if ($item.LastWriteTime -ge $cutoff) { continue }
    $size = if ($item.PSIsContainer) { (Get-ChildItem $item.FullName -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum } else { $item.Length }
    Remove-Item $item.FullName -Recurse -Force -ErrorAction SilentlyContinue
    if (-not (Test-Path $item.FullName)) { $freed += $size }
  }
}
Clear-RecycleBin -DriveLetter C -Force -ErrorAction SilentlyContinue
Log "freed $([math]::Round($freed/1MB,1)) MB"

foreach ($item in Get-ChildItem "$HOME\Downloads" -Force -ErrorAction SilentlyContinue) {
  if ($item.LastWriteTime -ge $cutoff -or $item.Name -eq 'desktop.ini') { continue }
  Move-Item $item.FullName (Join-Path $leftovers $item.Name) -Force -ErrorAction SilentlyContinue
  Log "moved $($item.Name) into MarcoLeftovers"
}

$freeGB = [math]::Round((Get-PSDrive C).Free / 1GB, 1)
Log "disk free: ${freeGB}GB"
if ($freeGB -lt 20) { Log "ATTENTION: low disk space" }
$agents = (Get-Process claude -ErrorAction SilentlyContinue | Measure-Object).Count
if ($agents -lt 4) { Log "ATTENTION: only $agents claude.exe running, expected 4" }

Add-Content -Path $log -Value $lines -Encoding utf8
$all = @(Get-Content $log)
if ($all.Count -gt 8000) { $all | Select-Object -Last 4000 | Set-Content -Path $log -Encoding utf8 }
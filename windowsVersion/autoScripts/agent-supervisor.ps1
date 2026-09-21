$ErrorActionPreference = 'Stop'
$scheduleFile = Join-Path $PSScriptRoot 'scheduledTasks.txt'
$cleanup = Join-Path $PSScriptRoot 'cleanup-watchdog.ps1'
$sessDir = Join-Path $env:USERPROFILE '.claude\sessions'

function send($agentName, $msg) {
  $live = Get-ChildItem -LiteralPath $sessDir -Filter '*.json' | ForEach-Object {
    $info = Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json
    if (-not $info.messagingSocketPath) { return }
    if (-not $info.procStart) { return }
    $proc = Get-Process -Id $info.pid -ErrorAction SilentlyContinue
    if (-not $proc) { return }
    if ($proc.StartTime.ToFileTimeUtc() -ne [int64]$info.procStart) { return }
    $info
  }
  $match = @($live | Where-Object { $_.name -eq $agentName })
  if ($match.Count -ne 1) { throw "expected exactly one live session named '$agentName', found $($match.Count)" }
  $target = $match[0]
  $keyFile = Get-ChildItem -LiteralPath $sessDir -Filter "$($target.pid).*.key" | Select-Object -First 1
  $token = (Get-Content -LiteralPath $keyFile.FullName -Raw | ConvertFrom-Json).peerToken
  $auth = @{ type = 'auth'; token = $token } | ConvertTo-Json -Compress
  $user = @{ type = 'user'; message = @{ role = 'user'; content = $msg } } | ConvertTo-Json -Compress
  $pipe = New-Object System.IO.Pipes.NamedPipeClientStream '.', ($target.messagingSocketPath -replace '^\\\\\.\\pipe\\', ''), ([System.IO.Pipes.PipeDirection]::InOut)
  try {
    $pipe.Connect(5000)
    $writer = New-Object System.IO.StreamWriter $pipe
    $writer.NewLine = "`n"
    $writer.WriteLine($auth)
    $writer.WriteLine($user)
    $writer.Flush()
  } finally {
    $pipe.Dispose()
  }
}

function clearSession($agentName) {
  Get-ChildItem -LiteralPath $sessDir -Filter '*.json' -ErrorAction SilentlyContinue | ForEach-Object {
    $info = Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json
    if ($info.name -ne $agentName) { return }
    Remove-Item -LiteralPath $_.FullName -Force
    Get-ChildItem -LiteralPath $sessDir -Filter "$($info.pid).*.key" | Remove-Item -Force
  }
}

function start_agent($agentName, $workDir) {
  Remove-Item -LiteralPath (Join-Path $workDir '.claude\scheduled_tasks.lock') -Force -ErrorAction SilentlyContinue
  clearSession $agentName
  Start-Process -FilePath 'claude' -ArgumentList "--remote-control $agentName -n $agentName" -WorkingDirectory $workDir -WindowStyle Maximized
}

function check_action() {
  if (-not (Test-Path -LiteralPath $scheduleFile)) {
    send 'winCoordinator' 'scheduler_failed'
    return -1
  }
  $now = Get-Date
  foreach ($line in Get-Content -LiteralPath $scheduleFile) {
    if (-not $line.Trim()) { continue }
    $parts = $line -split ',' | ForEach-Object { $_.Trim() }
    $time = [datetime]::ParseExact($parts[0], 'HH:mm', $null)
    $scheduled = Get-Date -Hour $time.Hour -Minute $time.Minute -Second 0
    if ([math]::Abs(($now - $scheduled).TotalMinutes) -lt 1) {
      send $parts[1] $parts[2]
      return 10
    }
  }
  return 1
}

Register-ObjectEvent -InputObject ([Microsoft.Win32.SystemEvents]) -EventName SessionEnding -Action {
  'win1', 'win2', 'win3', 'winCoordinator' | ForEach-Object { clearSession $_ }
} | Out-Null

while ($true) {
  try {
    (New-Object Net.Sockets.TcpClient('api.anthropic.com', 443)).Dispose()
    break
  } catch {
    Start-Sleep -Seconds 5
  }
}

start_agent 'win1' 'C:\data\fearlessBranch1'
start_agent 'win2' 'C:\data\fearlessBranch2'
start_agent 'win3' 'C:\data\fearlessBranch3'
start_agent 'winCoordinator' 'C:\data\winCoordinator'

Start-Sleep -Seconds 60

$lastCleanup = Get-Date
try {
  while ($true) {
    $res = check_action
    if ($res -eq -1) { break }
    if (((Get-Date) - $lastCleanup).TotalHours -ge 1) {
      $lastCleanup = Get-Date
      & $cleanup
    }
    Start-Sleep -Seconds ($res * 60)
  }
} catch { #any crash anywhere makes it all stop
  send 'winCoordinator' 'scheduler_failed'
}
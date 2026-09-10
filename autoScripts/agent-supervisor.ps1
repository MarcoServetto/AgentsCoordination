$ErrorActionPreference = 'Stop'
$scheduleFile = 'C:\data\winCoordinator\config\scheduledTasks.txt'
$cleanup = 'C:\data\winCoordinator\scripts\cleanup-watchdog.ps1'
$sessDir = Join-Path $env:USERPROFILE '.claude\sessions'

function send($agentName, $msg) {
  $live = Get-ChildItem -LiteralPath $sessDir -Filter '*.json' | ForEach-Object {
    $info = Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json
    if (-not $info.messagingSocketPath) { return }
    if (-not (Get-Process -Id $info.pid -ErrorAction SilentlyContinue)) { return }
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

function start_agent($agentName, $workDir) {
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

while ($true) {
  try {
    Invoke-WebRequest -Uri 'https://api.anthropic.com/' -TimeoutSec 10 -UseBasicParsing | Out-Null
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
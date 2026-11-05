$ErrorActionPreference = 'Stop'
$outDir = Join-Path $env:TEMP 'claude-usage-check'
$cacheFile = Join-Path $outDir 'last-check.json'
$maxCacheAgeMinutes = 15

if ((Test-Path $cacheFile) -and (((Get-Date) - (Get-Item $cacheFile).LastWriteTime).TotalMinutes -lt $maxCacheAgeMinutes)) {
  $cache = Get-Content $cacheFile -Raw | ConvertFrom-Json
  Write-Output $cache.sessionLine
  Write-Output $cache.weeklyLine
  return
}

$credentials = [IO.Path]::Combine($HOME, '.claude', '.credentials.json')
$token = (Get-Content $credentials -Raw | ConvertFrom-Json).claudeAiOauth.accessToken
if (-not $token) { throw "no claudeAiOauth.accessToken in ${credentials}: is Claude Code logged in?" }
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$raw = Join-Path $outDir "usage_$(Get-Date -Format yyyyMMdd_HHmmss).json"
$response = Invoke-WebRequest -UseBasicParsing -Uri 'https://api.anthropic.com/api/oauth/usage' -Headers @{ Authorization = "Bearer $token"; 'anthropic-beta' = 'oauth-2025-04-20' }
Set-Content -Path $raw -Value $response.Content
$d = $response.Content | ConvertFrom-Json

$now = [datetimeoffset]::UtcNow
$sessionReset = [datetimeoffset]::Parse($d.five_hour.resets_at)
$weeklyReset = [datetimeoffset]::Parse($d.seven_day.resets_at)
$left = [math]::Max(0, [math]::Floor(($sessionReset - $now).TotalMinutes))
$sessionLine = "Current session: $([math]::Round($d.five_hour.utilization))% used, started $($sessionReset.AddHours(-5).ToLocalTime().ToString('HH:mm')), resets in $([math]::Floor($left / 60))h $($left % 60)m"
$weeklyLine = "Weekly limits: $([math]::Round($d.seven_day.utilization))% used, resets $($weeklyReset.ToLocalTime().ToString('ddd HH:mm'))"
@{ timestamp = $now.ToString('o'); sessionLine = $sessionLine; weeklyLine = $weeklyLine } | ConvertTo-Json | Set-Content -Path $cacheFile
Write-Output $sessionLine
Write-Output $weeklyLine

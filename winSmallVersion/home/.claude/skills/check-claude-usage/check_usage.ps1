$ErrorActionPreference = 'Stop'
$outDir = Join-Path $env:TEMP 'claude-usage-check'
$cacheFile = Join-Path $outDir 'last-usage.json'
$maxCacheAgeMinutes = 15

if (-not ((Test-Path $cacheFile) -and (((Get-Date) - (Get-Item $cacheFile).LastWriteTime).TotalMinutes -lt $maxCacheAgeMinutes))) {
  $credentials = [IO.Path]::Combine($HOME, '.claude', '.credentials.json')
  $token = (Get-Content $credentials -Raw | ConvertFrom-Json).claudeAiOauth.accessToken
  if (-not $token) { throw "no claudeAiOauth.accessToken in ${credentials}: is Claude Code logged in?" }
  New-Item -ItemType Directory -Force -Path $outDir | Out-Null
  $response = Invoke-WebRequest -UseBasicParsing -Uri 'https://api.anthropic.com/api/oauth/usage' -Headers @{ Authorization = "Bearer $token"; 'anthropic-beta' = 'oauth-2025-04-20' }
  Set-Content -Path $cacheFile -Value $response.Content
}

$d = Get-Content $cacheFile -Raw | ConvertFrom-Json
$now = [datetimeoffset]::UtcNow
function Used($k) { "$([math]::Round($d.$k.utilization))% used" }
if ($null -eq $d.five_hour.resets_at) {
  Write-Output "Current session: $(Used 'five_hour'), not started"
} else {
  $sessionReset = [datetimeoffset]$d.five_hour.resets_at
  $left = [math]::Max(0, [math]::Floor(($sessionReset - $now).TotalMinutes))
  Write-Output "Current session: $(Used 'five_hour'), started $($sessionReset.AddHours(-5).ToLocalTime().ToString('HH:mm')), resets in $([math]::Floor($left / 60))h $($left % 60)m"
}
if ($null -eq $d.seven_day.resets_at) {
  Write-Output "Weekly limits: $(Used 'seven_day'), not started"
} else {
  Write-Output "Weekly limits: $(Used 'seven_day'), resets $(([datetimeoffset]$d.seven_day.resets_at).ToLocalTime().ToString('ddd HH:mm'))"
}
Write-Output "Read at $((Get-Item $cacheFile).LastWriteTime.ToString('HH:mm'))"

$ErrorActionPreference = 'Stop'
# Nothing but this fetch stands between an agent and the reset the repository
# currently describes, so this file has no reason to ever change.
$url = 'https://raw.githubusercontent.com/MarcoServetto/AgentsCoordination/main/windowsVersion/reset-body.ps1'
$body = Join-Path $env:TEMP 'reset-body.ps1'
Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $body
& $body

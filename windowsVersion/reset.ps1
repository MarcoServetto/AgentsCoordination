$ErrorActionPreference = 'Stop'
$repo = $PSScriptRoot
$data = 'C:\data'
$userHome = $HOME

function Nuke($path) {
  if (-not (Test-Path -LiteralPath $path)) { return }
  Write-Output "deleting $path"
  if ((Get-Item -LiteralPath $path -Force).PSIsContainer) { cmd /c rmdir /s /q "$path"; return }
  Remove-Item -LiteralPath $path -Force
}
function Run([string]$exe, [string[]]$cmdArgs) {
  & $exe @cmdArgs
  if ($LASTEXITCODE -ne 0) { throw "$exe $($cmdArgs -join ' ') failed with exit code $LASTEXITCODE" }
}

$parents = [ordered]@{
  Commons = "FearlessLang"; Frontend = "FearlessLang"; Coordinator = "FearlessLang"
  StandardLibrary = "FearlessLang"; Controllers = "FearlessLang"
  ZeroToHero = "MarcoServetto"; FearlessTour = "MarcoServetto"
}
$branches = 'fearlessBranch1', 'fearlessBranch2', 'fearlessBranch3'
$keep = @('AgentsCoordination', 'winCoordinator', 'tools', 'fearlessPaper', 'accounts.txt') + $branches

foreach ($item in Get-ChildItem $data -Force) { if ($keep -notcontains $item.Name) { Nuke $item.FullName } }
New-Item -ItemType Directory -Force -Path "$data\winCoordinator" | Out-Null
foreach ($item in Get-ChildItem "$data\winCoordinator" -Force) { Nuke $item.FullName }
foreach ($b in $branches) {
  New-Item -ItemType Directory -Force -Path "$data\$b" | Out-Null
  foreach ($item in Get-ChildItem "$data\$b" -Force) { if ($parents.Keys -notcontains $item.Name) { Nuke $item.FullName } }
  foreach ($r in $parents.Keys) {
    if (Test-Path "$data\$b\$r") { continue }
    Run git @('clone', '--quiet', "https://github.com/marcoautomation2/$r.git", "$data\$b\$r")
    Run git @('-C', "$data\$b\$r", 'remote', 'add', 'upstream', "https://github.com/$($parents[$r])/$r.git")
  }
}
Copy-Item -Recurse -Force "$repo\data\*" $data
foreach ($b in $branches) { Push-Location "$data\$b"; & "$repo\home\.claude\skills\align-branches\align-branches.ps1"; Pop-Location }

foreach ($n in 'skills', 'commands', 'agents', 'settings.local.json', 'keybindings.json', 'CLAUDE.local.md') { Nuke "$userHome\.claude\$n" }
foreach ($p in Get-ChildItem "$userHome\.claude\projects" -Directory -ErrorAction SilentlyContinue) { Nuke "$($p.FullName)\memory" }
Copy-Item -Recurse -Force "$repo\home\*" $userHome

Get-ScheduledTask | Where-Object { $_.TaskName -like 'Claude*' -and $_.TaskName -ne 'ClaudeAgentSupervisor' } | Unregister-ScheduledTask -Confirm:$false
Register-ScheduledTask -TaskName ClaudeAgentSupervisor -Force `
  -Action (New-ScheduledTaskAction -Execute powershell.exe -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File $repo\autoScripts\agent-supervisor.ps1") `
  -Trigger (New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME) `
  -Principal (New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest) `
  -Settings (New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan) -MultipleInstances IgnoreNew -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries) | Out-Null
Write-Output 'rebooting'
Restart-Computer -Force

$ErrorActionPreference = 'Stop'
# This script runs from wherever reset.ps1 downloaded it, so it is free to delete
# and reclone the checkout's own copy below.
$repoRoot = 'C:\data\AgentsCoordination'
$repo = "$repoRoot\windowsVersion"
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

Nuke $repoRoot
Run git @('clone', '--quiet', 'https://github.com/MarcoServetto/AgentsCoordination.git', $repoRoot)
Run git @('-C', $repoRoot, 'remote', 'add', 'fork', 'https://github.com/marcoautomation2/AgentsCoordination.git')

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
  foreach ($item in Get-ChildItem "$data\$b" -Force) { Nuke $item.FullName }
  foreach ($r in $parents.Keys) {
    Run git @('clone', '--quiet', "https://github.com/marcoautomation2/$r.git", "$data\$b\$r")
    Run git @('-C', "$data\$b\$r", 'remote', 'add', 'upstream', "https://github.com/$($parents[$r])/$r.git")
  }
}
Copy-Item -Recurse -Force "$repo\data\*" $data
foreach ($n in 'eclipse', 'eclipse-workspace', 'flexmark') { Nuke "$data\tools\$n" }
Nuke "$userHome\eclipse-workspace"
New-Item -ItemType Directory -Force -Path "$data\tools\flexmark" | Out-Null
Run curl.exe @('-fsSL', '-o', "$data\tools\eclipse.zip", 'https://www.eclipse.org/downloads/download.php?file=/technology/epp/downloads/release/2026-06/R/eclipse-java-2026-06-R-win32-x86_64.zip&r=1')
Run tar.exe @('-xf', "$data\tools\eclipse.zip", '-C', "$data\tools")
Nuke "$data\tools\eclipse.zip"
foreach ($a in 'flexmark', 'flexmark-ext-tables', 'flexmark-util-ast', 'flexmark-util-builder', 'flexmark-util-collection', 'flexmark-util-data', 'flexmark-util-dependency', 'flexmark-util-format', 'flexmark-util-html', 'flexmark-util-misc', 'flexmark-util-options', 'flexmark-util-sequence', 'flexmark-util-visitor') {
  Run curl.exe @('-fsSL', '-o', "$data\tools\flexmark\$a-0.64.8.jar", "https://repo1.maven.org/maven2/com/vladsch/flexmark/$a/0.64.8/$a-0.64.8.jar")
}
Run curl.exe @('-fsSL', '-o', "$data\tools\flexmark\annotations-24.0.1.jar", 'https://repo1.maven.org/maven2/org/jetbrains/annotations/24.0.1/annotations-24.0.1.jar')
foreach ($b in $branches) {
  Copy-Item -Force "$repo\LocalResources.java" "$data\$b\Coordinator\Build\src\resources\LocalResources.java"
  Push-Location "$data\$b"; & "$repo\home\.claude\skills\align-branches\align-branches.ps1"; Pop-Location
}

Nuke "$env:LOCALAPPDATA\Temp\claude"
foreach ($n in 'skills', 'commands', 'agents', 'hooks', 'settings.local.json', 'keybindings.json', 'CLAUDE.local.md') { Nuke "$userHome\.claude\$n" }
foreach ($p in Get-ChildItem "$userHome\.claude\projects" -Directory -ErrorAction SilentlyContinue) { Nuke "$($p.FullName)\memory" }
Copy-Item -Recurse -Force "$repo\home\*" $userHome

$sysPol = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
Set-ItemProperty $sysPol HideFastUserSwitching 1 -Type DWord
Set-ItemProperty $sysPol DisableLockWorkstation 1 -Type DWord
Run auditpol @('/set', '/subcategory:Other Logon/Logoff Events', '/success:enable', '/failure:enable')

Get-ScheduledTask | Where-Object { $_.TaskName -like 'Claude*' -and @('ClaudeAgentSupervisor', 'ClaudeSessionGuard') -notcontains $_.TaskName } | Unregister-ScheduledTask -Confirm:$false
Register-ScheduledTask -TaskName ClaudeAgentSupervisor -Force `
  -Action (New-ScheduledTaskAction -Execute powershell.exe -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File $repo\autoScripts\agent-supervisor.ps1") `
  -Trigger (New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME) `
  -Principal (New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest) `
  -Settings (New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan) -MultipleInstances IgnoreNew -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries) | Out-Null
$guard = "function gone { -not (Get-Process explorer -IncludeUserName -ErrorAction SilentlyContinue | Where-Object UserName -like '*\$env:USERNAME') }; if ((gone) -and ((Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime).TotalMinutes -gt 5) { Start-Sleep 180; if (gone) { Restart-Computer -Force } }"
Register-ScheduledTask -TaskName ClaudeSessionGuard -Force `
  -Action (New-ScheduledTaskAction -Execute powershell.exe -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -EncodedCommand $([Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($guard)))") `
  -Trigger (New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 1) -RepetitionDuration (New-TimeSpan -Days 9999)) `
  -Principal (New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest) `
  -Settings (New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 10) -MultipleInstances IgnoreNew -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries) | Out-Null
Write-Output 'rebooting'
Restart-Computer -Force

$ErrorActionPreference = "Stop"

$lines = Get-Content C:\data\accounts.txt
$i = [array]::IndexOf($lines, "GitHub token:")
if ($i -lt 0) { throw "C:\data\accounts.txt has no line reading exactly 'GitHub token:'" }
$env:GH_TOKEN = $lines[$i + 1].Trim()

function Run([string]$exe, [string[]]$cmdArgs) {
  & $exe @cmdArgs
  if ($LASTEXITCODE -ne 0) { throw "$exe $($cmdArgs -join ' ') failed with exit code $LASTEXITCODE" }
}

$parents = [ordered]@{
  Commons = "FearlessLang"; Frontend = "FearlessLang"; Coordinator = "FearlessLang"
  StandardLibrary = "FearlessLang"; EclipsePlugin = "FearlessLang"
  ZeroToHero = "MarcoServetto"; FearlessTour = "MarcoServetto"
}
foreach ($repo in $parents.Keys) {
  Write-Output "=== $repo"
  Run gh @("repo", "sync", "marcoautomation2/$repo", "--source", "$($parents[$repo])/$repo", "--force")
  Run git @("-C", $repo, "config", "core.autocrlf", "false")
  Run git @("-C", $repo, "fetch", "origin", "main")
  Run git @("-C", $repo, "checkout", "--force", "-B", "main", "origin/main")
  Run git @("-C", $repo, "clean", "-x", "-d", "--force", "-e", "test/mainCoordinator/LocalResources.java")
}

if (Test-Path out) { Remove-Item -Recurse -Force out }
Write-Output "=== aligned"

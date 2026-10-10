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
  StandardLibrary = "FearlessLang"; Controllers = "FearlessLang"
  ZeroToHero = "MarcoServetto"; FearlessTour = "MarcoServetto"
}
foreach ($repo in $parents.Keys) {
  Write-Output "=== $repo"
  Run gh @("repo", "sync", "marcoautomation2/$repo", "--source", "$($parents[$repo])/$repo", "--force")
  $prs = gh pr list --repo "$($parents[$repo])/$repo" --state open --limit 200 --json headRefName,headRepositoryOwner
  if ($LASTEXITCODE -ne 0) { throw "gh pr list $repo failed with exit code $LASTEXITCODE" }
  $open = $prs | ConvertFrom-Json | Where-Object { $_.headRepositoryOwner.login -eq "marcoautomation2" } | ForEach-Object { $_.headRefName }
  $all = gh api --paginate "repos/marcoautomation2/$repo/branches" --jq ".[].name"
  if ($LASTEXITCODE -ne 0) { throw "gh api branches $repo failed with exit code $LASTEXITCODE" }
  foreach ($b in $all) { if ($b -ne "main" -and $open -notcontains $b) { Run gh @("api", "-X", "DELETE", "repos/marcoautomation2/$repo/git/refs/heads/$b") } }
  Run git @("-C", $repo, "config", "core.autocrlf", "false")
  Run git @("-C", $repo, "fetch", "origin", "main")
  Run git @("-C", $repo, "checkout", "--force", "-B", "main", "origin/main")
  Run git @("-C", $repo, "clean", "-x", "-d", "--force", "-e", "Build/src/resources/LocalResources.java")
  if ($repo -eq "FearlessTour") { Copy-Item -Force C:\data\tools\flexmark\*.jar "$repo\externalJars" }
}

if (Test-Path out) { Remove-Item -Recurse -Force out }
Write-Output "=== aligned"

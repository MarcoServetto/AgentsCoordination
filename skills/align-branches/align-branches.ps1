```powershell
$ErrorActionPreference = "Stop"

$lines = Get-Content C:\data\accounts.txt
$i = [array]::IndexOf($lines, "GitHub token:")
if ($i -lt 0) { throw "C:\data\accounts.txt has no line reading exactly 'GitHub token:'" }
$env:GH_TOKEN = $lines[$i + 1].Trim()

function Run([string]$exe, [string[]]$cmdArgs) {
  & $exe @cmdArgs
  if ($LASTEXITCODE -ne 0) { throw "$exe $($cmdArgs -join ' ') failed with exit code $LASTEXITCODE" }
}

Write-Output "=== Commons"
Run gh @("repo", "sync", "marcoautomation2/Commons", "--source", "FearlessLang/Commons", "--force")
Run git @("-C", "Commons", "fetch", "origin", "main")
Run git @("-C", "Commons", "checkout", "--force", "-B", "main", "origin/main")
Run git @("-C", "Commons", "clean", "-x", "-d", "--force")

Write-Output "=== Frontend"
Run gh @("repo", "sync", "marcoautomation2/Frontend", "--source", "FearlessLang/Frontend", "--force")
Run git @("-C", "Frontend", "fetch", "origin", "main")
Run git @("-C", "Frontend", "checkout", "--force", "-B", "main", "origin/main")
Run git @("-C", "Frontend", "clean", "-x", "-d", "--force")

Write-Output "=== Coordinator"
Run gh @("repo", "sync", "marcoautomation2/Coordinator", "--source", "FearlessLang/Coordinator", "--force")
Run git @("-C", "Coordinator", "fetch", "origin", "main")
Run git @("-C", "Coordinator", "checkout", "--force", "-B", "main", "origin/main")
Run git @("-C", "Coordinator", "clean", "-x", "-d", "--force", "-e", "test/mainCoordinator/LocalResources.java")

Write-Output "=== StandardLibrary"
Run gh @("repo", "sync", "marcoautomation2/StandardLibrary", "--source", "FearlessLang/StandardLibrary", "--force")
Run git @("-C", "StandardLibrary", "fetch", "origin", "main")
Run git @("-C", "StandardLibrary", "checkout", "--force", "-B", "main", "origin/main")
Run git @("-C", "StandardLibrary", "clean", "-x", "-d", "--force")

Write-Output "=== EclipsePlugin"
Run gh @("repo", "sync", "marcoautomation2/EclipsePlugin", "--source", "FearlessLang/EclipsePlugin", "--force")
Run git @("-C", "EclipsePlugin", "fetch", "origin", "main")
Run git @("-C", "EclipsePlugin", "checkout", "--force", "-B", "main", "origin/main")
Run git @("-C", "EclipsePlugin", "clean", "-x", "-d", "--force")

Write-Output "=== ZeroToHero"
Run gh @("repo", "sync", "marcoautomation2/ZeroToHero", "--source", "MarcoServetto/ZeroToHero", "--force")
Run git @("-C", "ZeroToHero", "fetch", "origin", "main")
Run git @("-C", "ZeroToHero", "checkout", "--force", "-B", "main", "origin/main")
Run git @("-C", "ZeroToHero", "clean", "-x", "-d", "--force")

Write-Output "=== FearlessTour"
Run gh @("repo", "sync", "marcoautomation2/FearlessTour", "--source", "MarcoServetto/FearlessTour", "--force")
Run git @("-C", "FearlessTour", "fetch", "origin", "main")
Run git @("-C", "FearlessTour", "checkout", "--force", "-B", "main", "origin/main")
Run git @("-C", "FearlessTour", "clean", "-x", "-d", "--force")

if (Test-Path out) { Remove-Item -Recurse -Force out }
Write-Output "=== aligned"
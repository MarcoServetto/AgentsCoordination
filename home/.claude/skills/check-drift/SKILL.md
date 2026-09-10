---
name: check-drift
description: List how this machine deviates from the state described by C:\data\AgentsCoordination, which is what reset.ps1 would delete or overwrite, so the user can decide what to keep, what to revert and what to add to the repository. Read-only.
---

# Checking the drift

The drift is what `C:\data\AgentsCoordination\reset.ps1` would delete or
overwrite. Collect it with the commands below, then report a numbered list,
one line per deviation (the path and what differs); change nothing.

```powershell
$repo = 'C:\data\AgentsCoordination'
git -C $repo status --short
git diff --no-index --stat "$repo\home\.claude\skills" "$HOME\.claude\skills"
git diff --no-index "$repo\home\.claude\CLAUDE.md" "$HOME\.claude\CLAUDE.md"
git diff --no-index "$repo\home\.claude\settings.json" "$HOME\.claude\settings.json"
Get-ChildItem "$HOME\.claude\projects\*\memory" | Select-Object FullName, Length
Get-ChildItem "$HOME\.claude\commands", "$HOME\.claude\agents", "$HOME\.claude\settings.local.json", "$HOME\.claude\keybindings.json", "$HOME\.claude\CLAUDE.local.md" -ErrorAction SilentlyContinue
Get-ChildItem C:\data, C:\data\winCoordinator, C:\data\fearlessBranch* -Force
Get-ScheduledTask | Where-Object { $_.TaskName -like 'Claude*' }
```

reset.ps1 keeps, in `C:\data`, only `AgentsCoordination`, `fearlessBranch1`,
`fearlessBranch2`, `fearlessBranch3`, `winCoordinator`, `tools` and
`accounts.txt`; in `winCoordinator` nothing; in each `fearlessBranchN` only
the seven repositories; under `$HOME\.claude` none of the five entries
listed above and, in each `projects\<slug>\memory`, only the `MEMORY.md`
of `$repo\home\.claude\projects`; among the tasks only
`ClaudeAgentSupervisor`. Everything else the commands list is drift, and so
is every diff line.

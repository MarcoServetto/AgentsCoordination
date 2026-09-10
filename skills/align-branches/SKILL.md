---
name: align-branches
description: Reset a fearlessBranch working copy to upstream. Use at the start of new work in a fearlessBranch folder.
---

# Aligning a working copy to upstream

Run this from the workspace whose repos are to be aligned, for example

```powershell
Set-Location C:\data\fearlessBranch1
& "$HOME\.claude\skills\align-branches\align-branches.ps1"
```

It syncs each of the seven forks from its parent, forces the local `main`
onto the fork, deletes every untracked and ignored file except
`Coordinator\test\mainCoordinator\LocalResources.java`, sets
`core.autocrlf false`, and deletes the workspace `out` folder. It reads the
GitHub token from `C:\data\accounts.txt`.

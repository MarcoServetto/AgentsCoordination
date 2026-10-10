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

For each of the seven repositories the script force-syncs the fork's `main`
to upstream, deletes from the fork every other branch that has no open PR on
the parent, and resets the local clone to `main`.
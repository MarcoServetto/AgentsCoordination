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
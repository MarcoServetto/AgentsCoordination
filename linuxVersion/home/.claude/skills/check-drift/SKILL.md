---
name: check-drift
description: List how this machine deviates from the state described by /data/AgentsCoordination/linuxVersion, which is what reset.sh would delete or overwrite, so the user can decide what to keep, what to revert and what to add to the repository. Read-only.
---

# Checking the drift

The drift is what `/data/AgentsCoordination/linuxVersion/reset.sh` would delete or
overwrite. Collect it with the commands below, then report a numbered list,
one line per deviation (the path and what differs); change nothing.

```bash
repo=/data/AgentsCoordination/linuxVersion
git -C /data/AgentsCoordination status --short
git diff --no-index --stat "$repo/home/.claude/skills" "$HOME/.claude/skills"
git diff --no-index "$repo/home/.claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
git diff --no-index "$repo/home/.claude/settings.json" "$HOME/.claude/settings.json"
ls -la "$HOME"/.claude/projects/*/memory
ls -la "$HOME"/.claude/commands "$HOME"/.claude/agents "$HOME"/.claude/settings.local.json "$HOME"/.claude/keybindings.json "$HOME"/.claude/CLAUDE.local.md 2>/dev/null
ls -la /data /data/linuxCoordinator /data/fearlessBranch*
ls -la "$HOME"/.config/autostart
```

reset.sh keeps, in `/data`, only `AgentsCoordination`, `fearlessBranch1`,
`fearlessBranch2`, `fearlessBranch3`, `linuxCoordinator`, `tools`, `fearlessPaper` and
`accounts.txt`; in `linuxCoordinator` nothing; in each `fearlessBranchN` only
the seven repositories; under `$HOME/.claude` none of the five entries
listed above and, in each `projects/<slug>/memory`, only the `MEMORY.md`
of `$repo/home/.claude/projects`; among the autostart entries only
`claude-agent-supervisor.desktop`. Everything else the commands list is drift, and so
is every diff line.

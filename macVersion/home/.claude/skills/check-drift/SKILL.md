---
name: check-drift
description: List how this machine deviates from the state described by /Users/Shared/data/AgentsCoordination/macVersion, which is what reset.sh would delete or overwrite, so the user can decide what to keep, what to revert and what to add to the repository. Read-only.
---

# Checking the drift

The drift is what `/Users/Shared/data/AgentsCoordination/macVersion/reset.sh` would delete or
overwrite. Collect it with the commands below, then report a numbered list,
one line per deviation (the path and what differs); change nothing.

```bash
repo=/Users/Shared/data/AgentsCoordination/macVersion
git -C /Users/Shared/data/AgentsCoordination status --short
git -C /Users/Shared/data/AgentsCoordination fetch origin
git -C /Users/Shared/data/AgentsCoordination merge --ff-only origin/main
git diff --no-index "$repo/data/gym" /Users/Shared/data/gym --stat
git diff --no-index --stat "$repo/home/.claude/skills" "$HOME/.claude/skills"
git diff --no-index "$repo/home/.claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
git diff --no-index "$repo/home/.claude/settings.json" "$HOME/.claude/settings.json"
git diff --no-index "$repo/home/Library/LaunchAgents/com.claude.agent-supervisor.plist" "$HOME/Library/LaunchAgents/com.claude.agent-supervisor.plist"
for b in fearlessBranch1 fearlessBranch2 fearlessBranch3; do git diff --no-index "$repo/LocalResources.java" "/Users/Shared/data/$b/Coordinator/Build/src/resources/LocalResources.java"; done
ls -la "$HOME"/.claude/projects/*/memory
ls -la "$HOME"/.claude/commands "$HOME"/.claude/agents "$HOME"/.claude/settings.local.json "$HOME"/.claude/keybindings.json "$HOME"/.claude/CLAUDE.local.md 2>/dev/null
ls -la /Users/Shared/data /Users/Shared/data/macCoordinator /Users/Shared/data/tools /Users/Shared/data/fearlessBranch*
ls -la "$HOME"/Library/LaunchAgents/com.claude.*
```

reset.sh keeps, in `/Users/Shared/data`, only `AgentsCoordination`, `fearlessBranch1`,
`fearlessBranch2`, `fearlessBranch3`, `macCoordinator`, `tools` and `accounts.txt`;
in `macCoordinator` nothing; in `tools` only `Eclipse.app` and
`flexmark`; in each `fearlessBranchN` only the seven repositories; under
`$HOME/.claude` none of the five entries listed above and, in each
`projects/<slug>/memory`, only the `MEMORY.md` of `$repo/home/.claude/projects`;
among the `com.claude.*` launch agents, only `com.claude.agent-supervisor.plist`.
Everything else the commands list is drift, and so is every diff line.

`$HOME/.claude/skills/synced` is the bundle of Anthropic skills that Claude Code itself keeps up to date.
It is never drift: leave every file under it, and every diff line for it, out of the report.

An empty `.claude` folder, in any folder of the listing, is never drift: leave it out of the report.
A `.claude` folder with any content is drift.

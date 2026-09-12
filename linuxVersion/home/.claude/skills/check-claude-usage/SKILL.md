---
name: check-claude-usage
description: Read the current Anthropic usage limits, both the rolling ~5-hour "Current session" and the "Weekly limits", through the usage endpoint of the claude.ai account Claude Code is logged in with.
---
# Checking claude.ai usage limits

Call
```bash
"$HOME/.claude/skills/check-claude-usage/check_usage.sh"
```
Result:
```
Current session: NN% used, resets in Xh Ym
Weekly limits: NN% used, resets <day> <time>
```
Report those two lines verbatim. Readings are cached for 15 minutes in
`${TMPDIR:-/tmp}/claude-usage-check/last-check.json`; one account, four agents,
so a fresh reading from any of them is valid for all. About a second when
not cached; don't call it in a tight loop.

If this fails do not attempt the process manually.
Report the error instead. The user must fix this manually.

This script depends on the OAuth token in `~/.claude/.credentials.json`,
which the running agents keep fresh, and on `jq`, `curl` and `python3`.

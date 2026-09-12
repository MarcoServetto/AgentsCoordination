#!/bin/bash
set -euo pipefail
outDir="${TMPDIR:-/tmp}/claude-usage-check"
cacheFile="$outDir/last-check.json"
maxCacheAgeMinutes=15

if [ -f "$cacheFile" ] && [ "$(( ($(date +%s) - $(stat -c %Y "$cacheFile")) / 60 ))" -lt "$maxCacheAgeMinutes" ]; then
  jq -r '.sessionLine, .weeklyLine' "$cacheFile" && exit 0
fi

token=$(jq -r '.claudeAiOauth.accessToken' "$HOME/.claude/.credentials.json")
[ -n "$token" ] && [ "$token" != null ] || { echo "no claudeAiOauth.accessToken in ~/.claude/.credentials.json: is Claude Code logged in?" >&2; exit 1; }
mkdir -p "$outDir"
raw="$outDir/usage_$(date +%Y%m%d_%H%M%S).json"
code=$(curl -s -o "$raw" -w '%{http_code}' -H "Authorization: Bearer $token" -H "anthropic-beta: oauth-2025-04-20" https://api.anthropic.com/api/oauth/usage)
[ "$code" = 200 ] || { echo "usage endpoint answered HTTP $code; raw response saved at $raw" >&2; exit 1; }

python3 - "$raw" "$cacheFile" <<'PY'
import json, sys
from datetime import datetime, timedelta, timezone
raw, cacheFile = sys.argv[1:]
d = json.load(open(raw))
now = datetime.now(timezone.utc)
def at(k): return datetime.fromisoformat(d[k]['resets_at'])
left = max(0, int((at('five_hour') - now).total_seconds() // 60))
started = (at('five_hour') - timedelta(hours=5)).astimezone().strftime('%H:%M')
session = f"Current session: {round(d['five_hour']['utilization'])}% used, started {started}, resets in {left // 60}h {left % 60}m"
weekly = f"Weekly limits: {round(d['seven_day']['utilization'])}% used, resets {at('seven_day').astimezone().strftime('%a %H:%M')}"
json.dump({'timestamp': now.isoformat(), 'sessionLine': session, 'weeklyLine': weekly}, open(cacheFile, 'w'))
print(session); print(weekly)
PY

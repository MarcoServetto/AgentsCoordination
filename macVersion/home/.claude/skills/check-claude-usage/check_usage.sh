#!/bin/bash
set -euo pipefail
outDir="${TMPDIR:-/tmp}/claude-usage-check"
cacheFile="$outDir/last-usage.json"
maxCacheAgeMinutes=15

if ! { [ -f "$cacheFile" ] && [ "$(( ($(date +%s) - $(stat -f %m "$cacheFile")) / 60 ))" -lt "$maxCacheAgeMinutes" ]; }; then
  token=$(security find-generic-password -s 'Claude Code-credentials' -w | jq -r '.claudeAiOauth.accessToken')
  [ -n "$token" ] && [ "$token" != null ] || { echo "no claudeAiOauth.accessToken in the keychain item 'Claude Code-credentials': is Claude Code logged in?" >&2; exit 1; }
  mkdir -p "$outDir"
  raw="$outDir/last-response.json"
  code=$(curl -s -o "$raw" -w '%{http_code}' -H "Authorization: Bearer $token" -H "anthropic-beta: oauth-2025-04-20" https://api.anthropic.com/api/oauth/usage)
  [ "$code" = 200 ] || { echo "usage endpoint answered HTTP $code; raw response saved at $raw" >&2; exit 1; }
  mv "$raw" "$cacheFile"
fi

python3 - "$cacheFile" <<'PY'
import json, os, sys
from datetime import datetime, timedelta, timezone
cacheFile = sys.argv[1]
d = json.load(open(cacheFile))
now = datetime.now(timezone.utc)
def used(k): return f"{round(d[k]['utilization'])}% used"
def reset(k): return datetime.fromisoformat(d[k]['resets_at'])
def session():
  if d['five_hour']['resets_at'] is None: return f"Current session: {used('five_hour')}, not started"
  left = max(0, int((reset('five_hour') - now).total_seconds() // 60))
  started = (reset('five_hour') - timedelta(hours=5)).astimezone().strftime('%H:%M')
  return f"Current session: {used('five_hour')}, started {started}, resets in {left // 60}h {left % 60}m"
def weekly():
  if d['seven_day']['resets_at'] is None: return f"Weekly limits: {used('seven_day')}, not started"
  return f"Weekly limits: {used('seven_day')}, resets {reset('seven_day').astimezone().strftime('%a %H:%M')}"
print(session()); print(weekly())
print(f"Read at {datetime.fromtimestamp(os.path.getmtime(cacheFile)).strftime('%H:%M')}")
PY

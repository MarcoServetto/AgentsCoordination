#!/bin/bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
scheduleFile="$here/scheduledTasks.txt"
cleanup="$here/cleanup-watchdog.sh"
sessDir="$HOME/.claude/sessions"
export PATH="$HOME/.local/bin:$PATH"

send() {
  python3 - "$sessDir" "$1" "$2" <<'PY'
import glob, json, os, socket, sys
sessDir, agentName, msg = sys.argv[1:]
live = []
for f in glob.glob(os.path.join(sessDir, '*.json')):
    info = json.load(open(f))
    if not info.get('messagingSocketPath'): continue
    try: os.kill(info['pid'], 0)
    except OSError: continue
    if info.get('name') == agentName: live.append(info)
if len(live) != 1: raise SystemExit(f"expected exactly one live session named '{agentName}', found {len(live)}")
target = live[0]
keyFile = glob.glob(os.path.join(sessDir, f"{target['pid']}.*.key"))[0]
token = json.load(open(keyFile))['peerToken']
auth = json.dumps({'type': 'auth', 'token': token})
user = json.dumps({'type': 'user', 'message': {'role': 'user', 'content': msg}})
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.settimeout(5)
s.connect(target['messagingSocketPath'])
s.sendall((auth + '\n' + user + '\n').encode())
s.close()
PY
}

start_agent() {
  ptyxis --new-window --maximize --working-directory "$2" -x "bash -lc 'claude --remote-control $1 -n $1'" &
}

check_action() {
  if [ ! -f "$scheduleFile" ]; then send linuxCoordinator scheduler_failed; echo -1; return; fi
  now=$(date +%s)
  while IFS= read -r line; do
    [ -n "${line// /}" ] || continue
    IFS=, read -r t agent msg <<<"$line"
    t=$(printf '%s' "$t" | sed 's/^ *//;s/ *$//'); agent=$(printf '%s' "$agent" | sed 's/^ *//;s/ *$//'); msg=$(printf '%s' "$msg" | sed 's/^ *//;s/ *$//')
    scheduled=$(date -d "today $t" +%s)
    diff=$(( now - scheduled )); diff=${diff#-}
    if [ "$diff" -lt 60 ]; then send "$agent" "$msg"; echo 10; return; fi
  done < "$scheduleFile"
  echo 1
}

until curl -s --max-time 5 -o /dev/null https://api.anthropic.com; do sleep 5; done

start_agent linux1 /data/fearlessBranch1
sleep 15
start_agent linux2 /data/fearlessBranch2
sleep 15
start_agent linux3 /data/fearlessBranch3
sleep 15
start_agent linuxCoordinator /data/linuxCoordinator

sleep 60

lastCleanup=$(date +%s)
trap 'send linuxCoordinator scheduler_failed' ERR
while true; do
  res=$(check_action)
  if [ "$res" = -1 ]; then break; fi
  if [ $(( $(date +%s) - lastCleanup )) -ge 3600 ]; then
    lastCleanup=$(date +%s)
    "$cleanup"
  fi
  sleep $(( res * 60 ))
done

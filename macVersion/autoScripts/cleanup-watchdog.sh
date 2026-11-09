#!/bin/bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
log=/Users/Shared/data/macCoordinator/logs/diagnostic.log
whitelist=$(grep -v '^[[:space:]]*#' "$here/process-whitelist.txt" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$')
mkdir -p "$(dirname "$log")"
lines=()
logLine() { lines+=("[$(date '+%Y-%m-%d %H:%M:%S')] $1"); }

killed=0
while IFS=$'\t' read -r pid exe; do
  [ "$pid" = "$$" ] && continue
  [ "$pid" = "$PPID" ] && continue
  case $exe in /System/*|/usr/libexec/*|/usr/sbin/*|/Library/Apple/*) continue;; esac
  cmdline=$(ps -o args= -p "$pid" 2>/dev/null || true)
  set -- $cmdline
  printf '%s\n%s\n%s\n' "${exe##*/}" "${1:+${1##*/}}" "${2:+${2##*/}}" | grep -Fxqi "$whitelist" && continue
  kill -9 "$pid" 2>/dev/null || continue
  logLine "killed $exe (pid $pid): $cmdline"
  killed=$((killed + 1))
done < <(python3 - "$USER" <<'PY'
import ctypes, subprocess, sys
libproc = ctypes.CDLL('/usr/lib/libproc.dylib')
def seconds(etime):
    days, _, clock = etime.rpartition('-')
    parts = [int(p) for p in clock.split(':')]
    while len(parts) < 3: parts.insert(0, 0)
    return int(days or 0) * 86400 + parts[0] * 3600 + parts[1] * 60 + parts[2]
for line in subprocess.run(['ps', '-u', sys.argv[1], '-o', 'pid=,etime='], capture_output=True, text=True).stdout.splitlines():
    pid, etime = line.split()
    if seconds(etime) < 3600: continue
    path = ctypes.create_string_buffer(4096)
    if libproc.proc_pidpath(int(pid), path, 4096) <= 0: continue
    print(f"{pid}\t{path.value.decode()}")
PY
)
[ "$killed" -eq 0 ] && logLine "process sweep: clean"

freed=0
while IFS= read -r item; do
  size=$(du -sk "$item" 2>/dev/null | cut -f1 || echo 0)
  rm -rf -- "$item" 2>/dev/null || true
  [ -e "$item" ] || freed=$((freed + size))
done < <(
  find "$HOME/.local/bin" -maxdepth 1 -name 'claude.old.*' -mtime +7 2>/dev/null
  find /private/tmp /private/var/tmp -mindepth 1 -maxdepth 1 -user "$USER" -mtime +7 2>/dev/null
  find "$HOME/.local/share/claude/versions" -mindepth 1 -maxdepth 1 -mtime +7 2>/dev/null
  find "$HOME/Downloads" -mindepth 1 -maxdepth 1 -mtime +7 2>/dev/null
)
rm -rf "$HOME/.Trash/"* 2>/dev/null || true
logLine "freed $(( freed / 1024 )) MB"

freeGB=$(df -g /System/Volumes/Data | tail -1 | awk '{print $4}')
logLine "disk free: ${freeGB}GB"
[ "$freeGB" -lt 20 ] && logLine "ATTENTION: low disk space"
agents=$({ pgrep -u "$USER" -f '^claude --remote-control' || true; } | wc -l | tr -d ' ')
[ "$agents" -lt 4 ] && logLine "ATTENTION: only $agents claude running, expected 4"

printf '%s\n' "${lines[@]}" >> "$log"
if [ "$(wc -l < "$log")" -gt 8000 ]; then tail -n 4000 "$log" > "$log.tmp" && mv "$log.tmp" "$log"; fi

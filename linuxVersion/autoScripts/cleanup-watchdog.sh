#!/bin/bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
log=/data/linuxCoordinator/logs/diagnostic.log
whitelistFile="$here/process-whitelist.txt"
leftovers="$HOME/Desktop/MarcoLeftovers"
mkdir -p "$(dirname "$log")"
lines=()
logLine() { lines+=("[$(date '+%Y-%m-%d %H:%M:%S')] $1"); }

whitelist=" $(grep -v '^\s*#' "$whitelistFile" | sed 's/^\s*//;s/\s*$//' | grep -v '^$' | tr '[:upper:]' '[:lower:]' | tr '\n' ' ') "
killed=0
while read -r pid etimes comm; do
  [ "$pid" = "$$" ] && continue
  [ "$pid" = "$PPID" ] && continue
  [ "$etimes" -lt 3600 ] && continue
  cmdline=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null || true)
  set -- $cmdline
  names="$comm ${1:+${1##*/}} ${2:+${2##*/}}"
  listed=0
  for n in $(echo "$names" | tr '[:upper:]' '[:lower:]'); do case "$whitelist" in *" $n "*) listed=1;; esac; done
  [ "$listed" -eq 1 ] && continue
  kill -9 "$pid" 2>/dev/null || continue
  logLine "killed $comm (pid $pid): $cmdline"
  killed=$((killed + 1))
done < <(ps -u "$USER" -o pid=,etimes=,comm=)
[ "$killed" -eq 0 ] && logLine "process sweep: clean"

freed=0
while IFS= read -r item; do
  size=$(du -sb "$item" 2>/dev/null | cut -f1 || echo 0)
  rm -rf -- "$item" 2>/dev/null || true
  [ -e "$item" ] || freed=$((freed + size))
done < <(
  find "$HOME/.local/bin" -maxdepth 1 -name 'claude.old.*' -mtime +7 2>/dev/null
  find /tmp /var/tmp -mindepth 1 -maxdepth 1 -user "$USER" -mtime +7 2>/dev/null
  find "$HOME/.local/share/claude/versions" -mindepth 1 -maxdepth 1 -mtime +7 2>/dev/null
)
rm -rf "$HOME/.local/share/Trash/files/"* "$HOME/.local/share/Trash/info/"* 2>/dev/null || true
logLine "freed $(( freed / 1048576 )) MB"

mkdir -p "$leftovers"
while IFS= read -r item; do
  mv -f -- "$item" "$leftovers/" 2>/dev/null || continue
  logLine "moved $(basename "$item") into MarcoLeftovers"
done < <(find "$HOME/Downloads" -mindepth 1 -maxdepth 1 -mtime +7 2>/dev/null)

freeGB=$(df -BG --output=avail / | tail -1 | tr -dc '0-9')
logLine "disk free: ${freeGB}GB"
[ "$freeGB" -lt 20 ] && logLine "ATTENTION: low disk space"
agents=$(pgrep -u "$USER" -x claude | wc -l)
[ "$agents" -lt 4 ] && logLine "ATTENTION: only $agents claude running, expected 4"

printf '%s\n' "${lines[@]}" >> "$log"
if [ "$(wc -l < "$log")" -gt 8000 ]; then tail -n 4000 "$log" > "$log.tmp" && mv "$log.tmp" "$log"; fi

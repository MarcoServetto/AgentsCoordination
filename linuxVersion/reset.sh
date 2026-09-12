#!/bin/bash
set -euo pipefail
repo="$(cd "$(dirname "$0")" && pwd)"
data=/data
userHome="$HOME"

nuke() {
  [ -e "$1" ] || [ -L "$1" ] || return 0
  echo "deleting $1"
  rm -rf -- "$1"
}

github_clone() {
  git init -q "$2"
  git -C "$2" remote add origin "$1"
  local shallow=true started=false
  for attempt in $(seq 1 60); do
    if [ "$started" = false ]; then git -C "$2" fetch -q --depth=1 origin main && started=true || { sleep 30; continue; }; fi
    git -C "$2" fetch -q --deepen=200 origin main || { sleep 30; continue; }
    shallow=$(git -C "$2" rev-parse --is-shallow-repository)
    [ "$shallow" = true ] || break
  done
  [ "$shallow" = false ] || exit 1
  git -C "$2" checkout -q -B main origin/main
}

declare -A parents=(
  [Commons]=FearlessLang [Frontend]=FearlessLang [Coordinator]=FearlessLang
  [StandardLibrary]=FearlessLang [Controllers]=FearlessLang
  [ZeroToHero]=MarcoServetto [FearlessTour]=MarcoServetto
)
repos="Commons Frontend Coordinator StandardLibrary Controllers ZeroToHero FearlessTour"
branches="fearlessBranch1 fearlessBranch2 fearlessBranch3"
keep=" AgentsCoordination linuxCoordinator tools accounts.txt $branches "

for item in "$data"/* "$data"/.[!.]*; do
  [ -e "$item" ] || continue
  case "$keep" in *" $(basename "$item") "*) ;; *) nuke "$item";; esac
done
mkdir -p "$data/linuxCoordinator"
for item in "$data"/linuxCoordinator/* "$data"/linuxCoordinator/.[!.]*; do [ -e "$item" ] || continue; nuke "$item"; done
for b in $branches; do
  mkdir -p "$data/$b"
  for item in "$data/$b"/* "$data/$b"/.[!.]*; do
    [ -e "$item" ] || continue
    case " $repos " in *" $(basename "$item") "*) ;; *) nuke "$item";; esac
  done
  for r in $repos; do
    [ -e "$data/$b/$r" ] && continue
    local_copy=$(ls -d "$data"/fearlessBranch*/"$r" 2>/dev/null | head -1 || true)
    if [ -n "$local_copy" ]; then
      git clone --quiet "$local_copy" "$data/$b/$r"
      git -C "$data/$b/$r" remote set-url origin "https://github.com/marcoautomation2/$r.git"
    else
      github_clone "https://github.com/marcoautomation2/$r.git" "$data/$b/$r"
    fi
    git -C "$data/$b/$r" remote add upstream "https://github.com/${parents[$r]}/$r.git"
  done
done
cp -r "$repo/data/." "$data"
for b in $branches; do (cd "$data/$b" && "$repo/home/.claude/skills/align-branches/align-branches.sh"); done

for n in skills commands agents settings.local.json keybindings.json CLAUDE.local.md; do nuke "$userHome/.claude/$n"; done
for p in "$userHome"/.claude/projects/*/; do [ -d "$p" ] && nuke "${p}memory"; done
cp -r "$repo/home/." "$userHome"
for d in "$data/linuxCoordinator" "$data"/fearlessBranch1 "$data"/fearlessBranch2 "$data"/fearlessBranch3; do
  jq --arg d "$d" '.projects[$d] = ((.projects[$d] // {}) + {hasTrustDialogAccepted: true})' "$userHome/.claude.json" > "$userHome/.claude.json.tmp"
  mv "$userHome/.claude.json.tmp" "$userHome/.claude.json"
done

mkdir -p "$userHome/.config/autostart"
for f in "$userHome"/.config/autostart/claude*.desktop; do
  [ -e "$f" ] || continue
  [ "$(basename "$f")" = claude-agent-supervisor.desktop ] || nuke "$f"
done
cat > "$userHome/.config/autostart/claude-agent-supervisor.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=ClaudeAgentSupervisor
Exec=$repo/autoScripts/agent-supervisor.sh
X-GNOME-Autostart-enabled=true
NoDisplay=true
DESKTOP
echo rebooting
sudo systemctl reboot

#!/bin/bash
set -euo pipefail
cd /
# This script runs from wherever reset.sh downloaded it, so it is free to delete
# and reclone the checkout's own copy below.
repoRoot=/data/AgentsCoordination
repo="$repoRoot/linuxVersion"
data=/data
userHome="$HOME"

nuke() {
  [ -e "$1" ] || [ -L "$1" ] || return 0
  echo "deleting $1"
  rm -rf -- "$1"
}

nuke "$repoRoot"
git clone --quiet https://github.com/MarcoServetto/AgentsCoordination.git "$repoRoot"
git -C "$repoRoot" remote add fork https://github.com/marcoautomation2/AgentsCoordination.git

declare -A parents=(
  [Commons]=FearlessLang [Frontend]=FearlessLang [Coordinator]=FearlessLang
  [StandardLibrary]=FearlessLang [Controllers]=FearlessLang
  [ZeroToHero]=MarcoServetto [FearlessTour]=MarcoServetto
)
repos="Commons Frontend Coordinator StandardLibrary Controllers ZeroToHero FearlessTour"
branches="fearlessBranch1 fearlessBranch2 fearlessBranch3"
keep=" AgentsCoordination linuxCoordinator tools accounts.txt vms pilotio $branches "

for item in "$data"/* "$data"/.[!.]*; do
  [ -e "$item" ] || continue
  case "$keep" in *" $(basename "$item") "*) ;; *) nuke "$item";; esac
done
mkdir -p "$data/linuxCoordinator"
for item in "$data"/linuxCoordinator/* "$data"/linuxCoordinator/.[!.]*; do [ -e "$item" ] || continue; nuke "$item"; done
for b in $branches; do
  mkdir -p "$data/$b"
  for item in "$data/$b"/* "$data/$b"/.[!.]*; do [ -e "$item" ] || continue; nuke "$item"; done
  for r in $repos; do
    git clone --quiet "https://github.com/marcoautomation2/$r.git" "$data/$b/$r"
    git -C "$data/$b/$r" remote add upstream "https://github.com/${parents[$r]}/$r.git"
  done
done
cp -r "$repo/data/." "$data"
for n in eclipse eclipse-workspace flexmark; do nuke "$data/tools/$n"; done
nuke "$userHome/eclipse-workspace"
mkdir -p "$data/tools/flexmark"
curl -fsSL -o "$data/tools/eclipse.tar.gz" 'https://www.eclipse.org/downloads/download.php?file=/technology/epp/downloads/release/2026-06/R/eclipse-java-2026-06-R-linux-gtk-x86_64.tar.gz&r=1'
tar -xzf "$data/tools/eclipse.tar.gz" -C "$data/tools"
nuke "$data/tools/eclipse.tar.gz"
for a in flexmark flexmark-ext-tables flexmark-util-ast flexmark-util-builder flexmark-util-collection flexmark-util-data flexmark-util-dependency flexmark-util-format flexmark-util-html flexmark-util-misc flexmark-util-options flexmark-util-sequence flexmark-util-visitor; do
  curl -fsSL -o "$data/tools/flexmark/$a-0.64.8.jar" "https://repo1.maven.org/maven2/com/vladsch/flexmark/$a/0.64.8/$a-0.64.8.jar"
done
curl -fsSL -o "$data/tools/flexmark/annotations-24.0.1.jar" https://repo1.maven.org/maven2/org/jetbrains/annotations/24.0.1/annotations-24.0.1.jar
for b in $branches; do
  cp "$repo/LocalResources.java" "$data/$b/Coordinator/Build/src/resources/LocalResources.java"
  (cd "$data/$b" && "$repo/home/.claude/skills/align-branches/align-branches.sh")
done

for n in skills commands agents hooks settings.local.json keybindings.json CLAUDE.local.md; do nuke "$userHome/.claude/$n"; done
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

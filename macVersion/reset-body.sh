#!/bin/bash
set -euo pipefail
cd /
# This script runs from wherever reset.sh downloaded it, so it is free to delete
# and reclone the checkout's own copy below.
repoRoot=/Users/Shared/data/AgentsCoordination
repo="$repoRoot/macVersion"
data=/Users/Shared/data
userHome="$HOME"
export PATH="$HOME/.local/bin:/opt/homebrew/bin:$PATH"

nuke() {
  [ -e "$1" ] || [ -L "$1" ] || return 0
  echo "deleting $1"
  rm -rf -- "$1"
}

nuke "$repoRoot"
git clone --quiet https://github.com/MarcoServetto/AgentsCoordination.git "$repoRoot"
git -C "$repoRoot" remote add fork https://github.com/marcoautomation2/AgentsCoordination.git

parent() { case $1 in ZeroToHero|FearlessTour) echo MarcoServetto;; *) echo FearlessLang;; esac; }
repos="Commons Frontend Coordinator StandardLibrary Controllers ZeroToHero FearlessTour"
branches="fearlessBranch1 fearlessBranch2 fearlessBranch3"
keep=" AgentsCoordination macCoordinator tools accounts.txt $branches "

for item in "$data"/* "$data"/.[!.]*; do
  [ -e "$item" ] || continue
  case "$keep" in *" $(basename "$item") "*) ;; *) nuke "$item";; esac
done
mkdir -p "$data/macCoordinator"
for item in "$data"/macCoordinator/* "$data"/macCoordinator/.[!.]*; do [ -e "$item" ] || continue; nuke "$item"; done
for b in $branches; do
  mkdir -p "$data/$b"
  for item in "$data/$b"/* "$data/$b"/.[!.]*; do [ -e "$item" ] || continue; nuke "$item"; done
  for r in $repos; do
    git clone --quiet "https://github.com/marcoautomation2/$r.git" "$data/$b/$r"
    git -C "$data/$b/$r" remote add upstream "https://github.com/$(parent $r)/$r.git"
  done
done
cp -R "$repo/data/." "$data"
for n in Eclipse.app eclipse-workspace flexmark; do nuke "$data/tools/$n"; done
nuke "$userHome/eclipse-workspace"
mkdir -p "$data/tools/flexmark"
curl -fsSL -o "$data/tools/eclipse.dmg" 'https://www.eclipse.org/downloads/download.php?file=/technology/epp/downloads/release/2026-06/R/eclipse-java-2026-06-R-macosx-cocoa-aarch64.dmg&r=1'
mnt=$(mktemp -d)
hdiutil attach -quiet -nobrowse -readonly -mountpoint "$mnt" "$data/tools/eclipse.dmg" </dev/null
cp -R "$mnt/Eclipse.app" "$data/tools/"
hdiutil detach -quiet "$mnt"
nuke "$data/tools/eclipse.dmg"
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
for f in "$userHome"/Library/LaunchAgents/com.claude.*.plist; do
  [ -e "$f" ] || continue
  [ "$(basename "$f")" = com.claude.agent-supervisor.plist ] || nuke "$f"
done
cp -R "$repo/home/." "$userHome"
for d in "$data/macCoordinator" "$data"/fearlessBranch1 "$data"/fearlessBranch2 "$data"/fearlessBranch3; do
  jq --arg d "$d" '.projects[$d] = ((.projects[$d] // {}) + {hasTrustDialogAccepted: true})' "$userHome/.claude.json" > "$userHome/.claude.json.tmp"
  mv "$userHome/.claude.json.tmp" "$userHome/.claude.json"
done
echo rebooting
sudo shutdown -r now

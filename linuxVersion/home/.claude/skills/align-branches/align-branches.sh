#!/bin/bash
set -euo pipefail

GH_TOKEN=$(awk '/^GitHub token:$/{getline; print; exit}' /data/accounts.txt)
[ -n "$GH_TOKEN" ] || { echo "/data/accounts.txt has no line reading exactly 'GitHub token:'" >&2; exit 1; }
export GH_TOKEN

declare -A parents=(
  [Commons]=FearlessLang [Frontend]=FearlessLang [Coordinator]=FearlessLang
  [StandardLibrary]=FearlessLang [Controllers]=FearlessLang
  [ZeroToHero]=MarcoServetto [FearlessTour]=MarcoServetto
)
for repo in Commons Frontend Coordinator StandardLibrary Controllers ZeroToHero FearlessTour; do
  echo "=== $repo"
  gh repo sync "marcoautomation2/$repo" --source "${parents[$repo]}/$repo" --force
  git -C "$repo" config core.autocrlf false
  git -C "$repo" fetch origin main
  git -C "$repo" checkout --force -B main origin/main
  git -C "$repo" clean -x -d --force -e Build/src/resources/LocalResources.java
done

rm -rf out
echo "=== aligned"

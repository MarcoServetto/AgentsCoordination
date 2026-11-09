#!/bin/bash
set -euo pipefail

GH_TOKEN=$(awk '/^GitHub token:$/{getline; print; exit}' /Users/Shared/data/accounts.txt)
[ -n "$GH_TOKEN" ] || { echo "/Users/Shared/data/accounts.txt has no line reading exactly 'GitHub token:'" >&2; exit 1; }
export GH_TOKEN

parent() { case $1 in ZeroToHero|FearlessTour) echo MarcoServetto;; *) echo FearlessLang;; esac; }
for repo in Commons Frontend Coordinator StandardLibrary Controllers ZeroToHero FearlessTour; do
  echo "=== $repo"
  gh repo sync "marcoautomation2/$repo" --source "$(parent $repo)/$repo" --force
  open=$(gh pr list --repo "$(parent $repo)/$repo" --state open --limit 200 --json headRefName,headRepositoryOwner --jq '.[] | select(.headRepositoryOwner.login == "marcoautomation2") | .headRefName' | tr '\n' ' ')
  all=$(gh api --paginate "repos/marcoautomation2/$repo/branches" --jq '.[].name')
  for b in $all; do
    case " main $open" in *" $b "*) ;; *) gh api -X DELETE "repos/marcoautomation2/$repo/git/refs/heads/$b" > /dev/null;; esac
  done
  git -C "$repo" config core.autocrlf false
  git -C "$repo" fetch origin main
  git -C "$repo" checkout --force -B main origin/main
  git -C "$repo" clean -x -d --force -e Build/src/resources/LocalResources.java
  if [ "$repo" = FearlessTour ]; then cp /Users/Shared/data/tools/flexmark/*.jar "$repo/externalJars/"; fi
done

rm -rf out
echo "=== aligned"

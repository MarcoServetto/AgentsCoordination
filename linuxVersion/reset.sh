#!/bin/bash
set -euo pipefail
# Nothing but this fetch stands between an agent and the reset the repository
# currently describes, so this file has no reason to ever change.
url=https://raw.githubusercontent.com/MarcoServetto/AgentsCoordination/main/linuxVersion/reset-body.sh
body=$(mktemp)
curl -fsSL "$url" -o "$body"
exec bash "$body"

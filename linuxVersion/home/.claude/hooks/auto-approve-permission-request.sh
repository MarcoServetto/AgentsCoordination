#!/bin/bash
set -euo pipefail
jq -n '{
  hookSpecificOutput: {
    hookEventName: "PermissionRequest",
    decision: { behavior: "allow" }
  }
}'

#!/usr/bin/env bash
set -euo pipefail

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required"
  exit 1
fi

payload='{"JobName":"UpcomingExpiredPrograms","TargetEnv":"CP-Dev","ForceRun":false}'

curl -sS \
  -X POST \
  -H "Content-Type: application/json" \
  -d "$payload" \
  http://localhost:7071/api/jobs/execute | cat

echo

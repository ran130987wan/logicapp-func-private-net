#!/usr/bin/env bash
set -euo pipefail

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required"
  exit 1
fi

contract="${LOGICAPP_FUNCTION_CONTRACT:-legacy_execute}"
endpoint="${FUNCTION_ENDPOINT:-http://localhost:7071/api/jobs/execute}"

if [[ "$contract" == "durable_jobs_api" ]]; then
  endpoint="${FUNCTION_ENDPOINT:-http://localhost:7071/api/jobs}"
  payload='{"jobName":"UpcomingExpiredPrograms","tenantId":null,"parameters":{}}'
else
  payload='{"JobName":"UpcomingExpiredPrograms","TargetEnv":"CP-Dev","ForceRun":false}'
fi

curl -sS \
  -X POST \
  -H "Content-Type: application/json" \
  -d "$payload" \
  "$endpoint" | cat

echo

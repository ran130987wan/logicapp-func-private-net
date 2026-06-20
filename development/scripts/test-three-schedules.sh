#!/usr/bin/env bash
set -euo pipefail

# Prefer system-installed dotnet/runtime when available.
export PATH="/usr/bin:$PATH"

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required"
  exit 1
fi

contract="${LOGICAPP_FUNCTION_CONTRACT:-legacy_execute}"
endpoint="${FUNCTION_ENDPOINT:-http://localhost:7071/api/jobs/execute}"

if [[ "$contract" == "durable_jobs_api" ]]; then
  endpoint="${FUNCTION_ENDPOINT:-http://localhost:7071/api/jobs}"
fi

if [[ "$contract" == "durable_jobs_api" ]]; then
  payloads=(
    '{"jobName":"UpcomingExpiredPrograms","tenantId":null,"parameters":{}}'
    '{"jobName":"WeeklyExpiredCleanup","tenantId":null,"parameters":{}}'
    '{"jobName":"HourlyReconciliation","tenantId":null,"parameters":{}}'
  )
else
  payloads=(
    '{"JobName":"UpcomingExpiredPrograms","TargetEnv":"CP-Dev","ForceRun":false}'
    '{"JobName":"WeeklyExpiredCleanup","TargetEnv":"CP-Dev","ForceRun":false}'
    '{"JobName":"HourlyReconciliation","TargetEnv":"CP-Dev","ForceRun":false}'
  )
fi

ok_count=0
index=1
for payload in "${payloads[@]}"; do
  echo "Invoking schedule #$index"
  response=$(curl -sS -X POST -H "Content-Type: application/json" -d "$payload" "$endpoint")
  echo "$response"
  if [[ "$contract" == "durable_jobs_api" ]]; then
    if echo "$response" | grep -q '"statusQueryGetUri"'; then
      ok_count=$((ok_count + 1))
    fi
  else
    if echo "$response" | grep -q '"status":"Success"\|"status": "Success"'; then
      ok_count=$((ok_count + 1))
    fi
  fi
  index=$((index + 1))
done

if [[ "$ok_count" -ne 3 ]]; then
  echo "Expected 3 successful invocations, got $ok_count"
  exit 1
fi

echo "PASS: Single Azure Function accepted 3 scheduler-style invocations"

#!/usr/bin/env bash
set -euo pipefail

# Prefer system-installed dotnet/runtime when available.
export PATH="/usr/bin:$PATH"

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required"
  exit 1
fi

endpoint="${FUNCTION_ENDPOINT:-http://localhost:7071/api/jobs/execute}"

payloads=(
  '{"JobName":"UpcomingExpiredPrograms","TargetEnv":"CP-Dev","ForceRun":false}'
  '{"JobName":"WeeklyExpiredCleanup","TargetEnv":"CP-Dev","ForceRun":false}'
  '{"JobName":"HourlyReconciliation","TargetEnv":"CP-Dev","ForceRun":false}'
)

ok_count=0
index=1
for payload in "${payloads[@]}"; do
  echo "Invoking schedule #$index"
  response=$(curl -sS -X POST -H "Content-Type: application/json" -d "$payload" "$endpoint")
  echo "$response"
  if echo "$response" | grep -q '"status":"Success"\|"status": "Success"'; then
    ok_count=$((ok_count + 1))
  fi
  index=$((index + 1))
done

if [[ "$ok_count" -ne 3 ]]; then
  echo "Expected 3 successful invocations, got $ok_count"
  exit 1
fi

echo "PASS: Single Azure Function accepted 3 scheduler-style invocations"

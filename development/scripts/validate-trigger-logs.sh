#!/usr/bin/env bash
set -euo pipefail

# Validate that all Logic App schedules trigger one Function endpoint and that
# Function request logs are present in Log Analytics.

RG_NAME="${RG_NAME:-rg-demo-dev-weu}"
SUBSCRIPTION_ID="${SUBSCRIPTION_ID:-$(az account show --query id -o tsv)}"
TIME_WINDOW="${TIME_WINDOW:-30m}"

if [[ -z "${SUBSCRIPTION_ID}" ]]; then
  echo "ERROR: unable to resolve subscription id. Run 'az login' first." >&2
  exit 1
fi

WORKFLOWS=(
  "logic-demo-expired-programs-dev-weu"
  "logic-demo-hourly-reconcile-dev-weu"
  "logic-demo-weekly-cleanup-dev-weu"
)

echo "Using subscription: ${SUBSCRIPTION_ID}"
echo "Using resource group: ${RG_NAME}"

echo
echo "== Triggering Recurrence for each workflow =="
for wf in "${WORKFLOWS[@]}"; do
  az rest \
    --method POST \
    --url "https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Logic/workflows/${wf}/triggers/Recurrence/run?api-version=2016-06-01" \
    --only-show-errors >/dev/null
  echo "triggered:${wf}"
done

echo
echo "== Latest workflow run statuses =="
printf "%s\n" "workflow|run_id|run_status|call_function_status"
for wf in "${WORKFLOWS[@]}"; do
  run_id="$(az rest --method GET --url "https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Logic/workflows/${wf}/runs?api-version=2016-06-01&\$top=1" --query "value[0].name" -o tsv)"
  run_status="$(az rest --method GET --url "https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Logic/workflows/${wf}/runs/${run_id}?api-version=2016-06-01" --query "properties.status" -o tsv)"
  action_status="$(az rest --method GET --url "https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Logic/workflows/${wf}/runs/${run_id}/actions?api-version=2016-06-01" --query "value[?name=='CallFunction'].properties.status | [0]" -o tsv)"
  printf "%s\n" "${wf}|${run_id}|${run_status}|${action_status}"
done

echo
echo "== Workflow endpoint wiring =="
printf "%s\n" "workflow|uri|job_name"
for wf in "${WORKFLOWS[@]}"; do
  uri="$(az rest --method GET --url "https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Logic/workflows/${wf}?api-version=2019-05-01" --query "properties.definition.actions.CallFunction.inputs.uri" -o tsv)"
  job_name="$(az rest --method GET --url "https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Logic/workflows/${wf}?api-version=2019-05-01" --query "properties.definition.actions.CallFunction.inputs.body.JobName" -o tsv)"
  printf "%s\n" "${wf}|${uri}|${job_name}"
done

echo
echo "== Function request logs (Log Analytics) =="
ai_name="$(az resource list -g "${RG_NAME}" --resource-type Microsoft.Insights/components --query "[0].name" -o tsv)"
if [[ -z "${ai_name}" ]]; then
  echo "ERROR: no Application Insights component found in ${RG_NAME}" >&2
  exit 1
fi
workspace_id="$(az monitor app-insights component show -a "${ai_name}" -g "${RG_NAME}" --query workspaceResourceId -o tsv)"
customer_id="$(az resource show --ids "${workspace_id}" --query properties.customerId -o tsv)"

az monitor log-analytics query \
  -w "${customer_id}" \
  --analytics-query "AppRequests | where TimeGenerated > ago(${TIME_WINDOW}) | where Url has '/api/jobs/execute' | project TimeGenerated, Name, ResultCode, Success | order by TimeGenerated desc | take 20" \
  -o table

echo
echo "Validation complete."

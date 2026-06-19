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
failed_workflows=0
for wf in "${WORKFLOWS[@]}"; do
  run_id="$(az rest --method GET --url "https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Logic/workflows/${wf}/runs?api-version=2016-06-01&\$top=1" --query "value[0].name" -o tsv)"
  run_status="$(az rest --method GET --url "https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Logic/workflows/${wf}/runs/${run_id}?api-version=2016-06-01" --query "properties.status" -o tsv)"
  action_status="$(az rest --method GET --url "https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Logic/workflows/${wf}/runs/${run_id}/actions?api-version=2016-06-01" --query "value[?name=='CallFunction'].properties.status | [0]" -o tsv)"
  printf "%s\n" "${wf}|${run_id}|${run_status}|${action_status}"

  if [[ -z "${run_id}" || "${run_status}" != "Succeeded" || "${action_status}" != "Succeeded" ]]; then
    echo "ERROR: validation failed for ${wf} (run_status=${run_status:-<missing>}, action_status=${action_status:-<missing>})" >&2
    failed_workflows=$((failed_workflows + 1))
  fi
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

request_count="$(az monitor log-analytics query \
  -w "${customer_id}" \
  --analytics-query "AppRequests | where TimeGenerated > ago(${TIME_WINDOW}) | where Url has '/api/jobs/execute' | summarize count()" \
  --query "tables[0].rows[0][0]" -o tsv)"

if [[ -z "${request_count}" || "${request_count}" -lt 3 ]]; then
  echo "ERROR: expected at least 3 function request logs in the last ${TIME_WINDOW}, got ${request_count:-0}" >&2
  exit 1
fi

if [[ "${failed_workflows}" -ne 0 ]]; then
  echo "ERROR: ${failed_workflows} workflow validations failed" >&2
  exit 1
fi

echo
echo "Validation complete: all workflows and request logs passed."

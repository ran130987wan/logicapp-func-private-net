#!/usr/bin/env bash
set -euo pipefail

repo="ran130987wan/logicapp-func-private-net"
branch="main"
required_checks=("validate" "three-trigger-test")

if ! command -v gh >/dev/null 2>&1; then
  echo "SKIP: gh CLI is not installed"
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "SKIP: jq is not installed"
  exit 0
fi

if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  echo "INFO: GITHUB_TOKEN environment variable is set."
  echo "INFO: In Codespaces this token often lacks branch-protection admin rights."
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "SKIP: gh is not authenticated. Run: gh auth login"
  exit 0
fi

if ! json=$(gh api \
  -H "Accept: application/vnd.github+json" \
  "/repos/${repo}/branches/${branch}/protection" 2>/tmp/verify-governance.err); then
  err_msg=$(cat /tmp/verify-governance.err || true)
  if echo "$err_msg" | grep -q "HTTP 403"; then
    if echo "$err_msg" | grep -qi "Upgrade to GitHub Pro"; then
      echo "FAIL: Branch protection not available for ${repo}:${branch} on current GitHub plan"
      echo "Hint: upgrade to GitHub Pro for private repos, or make the repository public"
    else
      echo "FAIL: GitHub API access denied (HTTP 403) for ${repo}:${branch}"
      echo "Hint: use an account/token with repo admin permissions"
    fi
    exit 1
  fi
  echo "FAIL: Unable to read branch protection for ${repo}:${branch}"
  echo "Details: ${err_msg}"
  exit 1
fi

require_pr=$(echo "$json" | jq -r '.required_pull_request_reviews != null')
strict=$(echo "$json" | jq -r '.required_status_checks.strict // false')

if [[ "$require_pr" != "true" ]]; then
  echo "FAIL: Pull request review requirement is not enabled"
  exit 1
fi

if [[ "$strict" != "true" ]]; then
  echo "FAIL: Required checks strict mode is not enabled"
  exit 1
fi

contexts=$(echo "$json" | jq -r '.required_status_checks.contexts[]?' | sort)

missing=0
for check in "${required_checks[@]}"; do
  if ! echo "$contexts" | grep -qx "$check"; then
    echo "FAIL: Missing required status check: $check"
    missing=1
  fi
done

if [[ "$missing" -ne 0 ]]; then
  exit 1
fi

echo "PASS: Governance verification succeeded for ${repo}:${branch}"
echo "Required checks present: ${required_checks[*]}"

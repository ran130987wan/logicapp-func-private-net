#!/usr/bin/env bash
set -euo pipefail

repo="ran130987wan/logicapp-func-private-net"
branch="main"

if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  echo "FAIL: GITHUB_TOKEN is set (integration token)."
  echo "Run: unset GITHUB_TOKEN"
  echo "Then authenticate with admin account: gh auth login"
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "FAIL: gh CLI is not installed"
  exit 1
fi

if ! gh auth status -h github.com >/dev/null 2>&1; then
  echo "FAIL: gh is not authenticated"
  echo "Run: gh auth login"
  exit 1
fi

echo "Applying branch protection for ${repo}:${branch}..."
payload=$(cat <<'JSON'
{
  "required_status_checks": {
    "strict": true,
    "contexts": [
      "validate",
      "three-trigger-test"
    ]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "required_approving_review_count": 1
  },
  "restrictions": null,
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "block_creations": false,
  "required_conversation_resolution": true,
  "lock_branch": false,
  "allow_fork_syncing": true
}
JSON
)

if ! gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  "/repos/${repo}/branches/${branch}/protection" \
  --input - 2>/tmp/fix-repo-access.err <<<"$payload"; then
  err_msg=$(cat /tmp/fix-repo-access.err || true)
  if echo "$err_msg" | grep -qi "Upgrade to GitHub Pro"; then
    echo "FAIL: Branch protection requires GitHub Pro for private repositories (or make repo public)."
    echo "Action: Upgrade account/repo plan, or switch repository visibility to public."
  else
    echo "FAIL: Unable to apply branch protection"
    echo "Details: ${err_msg}"
  fi
  exit 1
fi

echo "Branch protection applied. Running governance verification..."
./development/scripts/verify-governance.sh

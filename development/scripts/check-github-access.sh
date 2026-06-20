#!/usr/bin/env bash
set -euo pipefail

if ! command -v gh >/dev/null 2>&1; then
  echo "FAIL: gh CLI is not installed"
  exit 1
fi

echo "== GitHub auth diagnostics =="
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  echo "GITHUB_TOKEN is set (likely integration token)."
  echo "Recommendation: unset GITHUB_TOKEN"
else
  echo "GITHUB_TOKEN is not set."
fi

if gh auth status -h github.com >/dev/null 2>&1; then
  echo "PASS: gh authenticated for github.com"
else
  echo "FAIL: gh not authenticated"
  echo "Run: gh auth login"
  exit 1
fi

echo "== Branch protection API probe =="
if gh api -H "Accept: application/vnd.github+json" /repos/ran130987wan/logicapp-func-private-net/branches/main/protection >/dev/null 2>/tmp/check-github-access.err; then
  echo "PASS: Branch protection API is accessible"
else
  err_msg=$(cat /tmp/check-github-access.err || true)
  echo "FAIL: Branch protection API not accessible"
  if echo "$err_msg" | grep -qi "Upgrade to GitHub Pro"; then
    echo "Reason: Branch protection requires GitHub Pro for private repos (or use a public repo)."
    echo "Action: Upgrade account/repo plan, or make repository public."
  else
    echo "Need repo admin permissions on your authenticated account/token"
  fi
  exit 1
fi

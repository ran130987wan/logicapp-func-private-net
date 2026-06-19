#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="${1:-./_scaffold-output}"

mkdir -p "${TARGET_DIR}"
cp -R scaffold/templates/. "${TARGET_DIR}/"

echo "Scaffold generated at: ${TARGET_DIR}"
echo "Next steps:"
echo "  1) Review values under infra/"
echo "  2) Configure GitHub secrets"
echo "  3) Run terraform validate + dotnet build"

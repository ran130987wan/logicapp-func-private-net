---
name: poc-bootstrap
description: "Use when setting up this POC from scratch in Linux Codespaces, installing tools, validating prerequisites, and running bootstrap."
---

# POC Bootstrap Skill

## Purpose

Prepare a fresh Linux environment for this repository and run bootstrap validation.

## Required checks

- az
- terraform
- dotnet
- func
- gh

## Steps

1. Install missing tools.
2. Verify versions.
3. Run development/scripts/bootstrap.sh.
4. Report blockers and minimal fixes.

## Tool install baseline (Linux)

```bash
sudo apt-get update -y
sudo apt-get install -y azure-cli terraform
sudo npm i -g azure-functions-core-tools@4 --unsafe-perm true
```

## Success criteria

- bootstrap.sh completes.
- dotnet restore/build pass.
- terraform validate passes.

## Memory guidance

- Persist stable setup/tool findings in /memories/repo/setup-notes.md.
- Use /memories/session/ for temporary in-run checkpoints only.

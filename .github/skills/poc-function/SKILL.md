---
name: poc-function
description: "Use when building, running, and validating the Azure Function app in this POC."
---

# POC Function Skill

## Purpose

Run build and local runtime checks for src/MaintenanceApp.

## Standard flow

```bash
dotnet restore src/MaintenanceApp/MaintenanceApp.csproj
dotnet build src/MaintenanceApp/MaintenanceApp.csproj -c Release
```

## Local execution

```bash
cd src/MaintenanceApp
func start
```

## Smoke test

```bash
./development/scripts/test-local-function.sh
```

## Success criteria

- Build succeeds.
- Local endpoint responds successfully.

## Memory guidance

- Add recurring runtime/toolchain fixes to /memories/repo/setup-notes.md.

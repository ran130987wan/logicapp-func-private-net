---
mode: ask
model: GPT-5.3-Codex
description: Add or update Logic App schedule entries in Terraform.
---

Help me add or update schedule entries in infra/variables.tf.

Input expected:
- name
- job_name
- frequency
- interval

Output expected:
1. Proposed new schedule object(s)
2. Validation checklist
3. Any naming collisions to resolve

---
description: "Audit the Halo-Halo catalog for staleness and maintenance issues (overdue review_by, old last_verified, deprecated references)."
---

# Halo-Halo Catalog Health Check

You are auditing the Halo-Halo patterns catalog.

## What to do
1) Run the staleness script:
   - `bash .halo-halo/halo-halo-upstream/scripts/staleness.sh .halo-halo/halo-halo-upstream/patterns`

2) Interpret the report:
   - Overdue reviews are BLOCKING (must be fixed before promoting new patterns).
   - last_verified warnings indicate likely drift—recommend review or re-verify.
   - Deprecated references should be resolved (update related/superseded_by or revise patterns).

3) Propose concrete next actions:
   - For each overdue pattern: suggest updated review_by/last_verified plan.
   - For deprecated references: suggest which patterns should be updated and how.

## Constraints
- Do not edit files unless the user asks you to.
- Keep output concise and actionable.

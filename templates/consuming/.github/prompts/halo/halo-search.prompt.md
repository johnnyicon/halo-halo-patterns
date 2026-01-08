---
description: Pattern Search — find relevant patterns for the current issue.
---

You are searching the Halo Patterns catalog.

## Step 1: Build Mini Context Packet

Extract from conversation:
- **Symptoms** — what's broken or unexpected
- **Stack** — language/framework/runtime
- **Touched Files** (if available) — helps narrow domain

If critical info is missing, ask for **one clarifying detail** (not multiple).

## Step 2: Search Catalog

Search `.patterns/catalog/patterns/` recursively:
- Match by: symptoms keywords, domain, tags, framework, runtime
- Prefer `status: validated` over `draft`
- Exclude `deprecated: true` unless user asks

## Step 3: Return Results

Provide **3–7 candidate patterns** with:
- Pattern ID
- Title
- Why it matches (1 sentence)
- Confidence level (high/medium/low)

Format:
```markdown
### Top Matches
1. **[pattern-id]** — Title  
   Why: <brief reason>  
   Confidence: high

2. ...
```

If no good matches, say so explicitly and suggest `/halo-gatekeeper` to create one.

---
description: "Write a pattern file from an approved Gatekeeper decision (local case or upstream draft)"
---

# Halo-Halo Write Pattern

You are writing a pattern file based on a Gatekeeper approval.

## What You Do

**Input required:**
- Gatekeeper decision (local case vs upstream pattern)
- Symptom description
- Root cause analysis
- Solution/fix summary
- Verification steps
- Related patterns (if any)

**Output depends on Gatekeeper routing:**

### Route A: Local Case (Default)

**Create:** `.halo-halo/local/cases/YYYY-MM-DD-<slug>.md`

**Front matter (minimal):**
```yaml
---
id: case-YYYYMMDD-001
date: YYYY-MM-DD
related_pattern_ids: []  # Optional - reference upstream patterns if applicable
resolution: success  # or partial, failed
---
```

**Required sections:**
1. **Context** - What was being worked on, what led to the issue
2. **Symptoms** - Observable behavior, error messages, unexpected results
3. **Root Cause** - Why it happened (technical explanation)
4. **Fix Summary** - What was changed to resolve it
5. **Verification** - How you confirmed the fix works
6. **Notes** - Additional observations, future considerations

**Sanitization rules (MANDATORY):**
- ❌ No client/company names → Use "client", "organization", "app"
- ❌ No internal URLs → Use example.com, api.example.com
- ❌ No API keys/tokens → Use "YOUR_API_KEY", "<redacted>"
- ❌ No repo-specific secrets → Use placeholders
- ❌ No PII (emails, names) → Use "user@example.com", "User A"
- ✅ Use generic class/model names if not framework-standard

---

### Route B: Upstream Pattern Draft (Only if Gatekeeper Says "Upstream")

**Create:** `.halo-halo/halo-halo-upstream/patterns/<language>/<framework>/<domain>/<pattern-slug>.md`

**Example paths:**
- Ruby/Rails: `patterns/ruby/rails/active_record/query-caching-issue.md`
- TypeScript/Next.js: `patterns/typescript/nextjs/server_actions/form-validation-pattern.md`
- Python/Django: `patterns/python/django/orm/n-plus-one-detection.md`

**Front matter (REQUIRED - all fields):**
```yaml
---
id: "pattern-{language}-{framework}-{slug}"
title: "Descriptive Pattern Title"
type: troubleshooting  # or implementation, anti-pattern, architecture
status: draft
confidence: medium  # low, medium, high
revision: 1
languages:
  - language: ruby
    versions: ">=3.0"
frameworks:
  - name: rails
    versions: ">=7.0 <9.0"
dependencies:
  - name: gem-name  # Optional - only if pattern requires specific gems/packages
    versions: ">=1.0"
domain: active_record  # or server_actions, orm, view_components, etc.
tags:
  - query-optimization
  - caching
  - performance
introduced: YYYY-MM-DD
last_verified: YYYY-MM-DD
review_by: YYYY-MM-DD  # 90 days from introduced
sanitized: true
related: []  # List of related pattern IDs
---
```

**Required sections by type:**

**For troubleshooting patterns:**
1. **Context** - When does this issue occur? What are the preconditions?
2. **Symptoms** - Observable behavior, error messages, performance issues
3. **Root Cause** - Technical explanation of why this happens
4. **Fix** - Step-by-step solution with code examples
5. **Verification Checklist**
   - [ ] Verify symptom is resolved
   - [ ] Check for side effects
   - [ ] Test edge cases
   - [ ] Performance impact measured

**For implementation patterns:**
1. **Context** - When to use this pattern, what problem it solves
2. **Usage** - Step-by-step implementation with code examples
3. **Tradeoffs** - Pros/cons, when NOT to use this
4. **Verification Checklist**
   - [ ] Feature works as expected
   - [ ] No regressions
   - [ ] Edge cases handled
   - [ ] Tests pass

**For anti-patterns:**
1. **Context** - When developers try this approach
2. **Why This Fails** - Technical explanation of the problem
3. **What to Do Instead** - The correct approach with examples
4. **Detection** - How to spot this in code reviews

**For architecture patterns:**
1. **Context** - Problem space, when this decision is relevant
2. **Decision** - The architectural choice and rationale
3. **Tradeoffs** - Benefits vs costs
4. **When to Use** - Specific scenarios
5. **When NOT to Use** - Anti-patterns, edge cases

**Code examples must:**
- Use syntax highlighting with language tags
- Show before/after when applicable
- Include comments explaining key points
- Be fully sanitized (no client-specific code)

**Sanitization (CRITICAL for upstream):**
- ❌ No internal URLs, company names, client names
- ❌ No API keys, tokens, credentials
- ❌ No PII (emails, names, addresses)
- ❌ No repo-specific class names (unless framework-standard)
- ✅ Use generic placeholders: User, Organization, Document, api.example.com
- ✅ Use framework-standard naming: ApplicationRecord, ApplicationController
- ✅ Generic method names: process, handle, transform

---

## Workflow

### Step 1: Confirm Gatekeeper Decision

**Ask user:**
```
Based on the Gatekeeper decision, I will create:
- [x] Local case in .halo-halo/local/cases/
- [ ] Upstream pattern draft in .halo-halo/halo-halo-upstream/patterns/

Is this correct? If upstream, which language/framework/domain?
```

### Step 2: Gather Required Information

**For local case:**
- Date (YYYY-MM-DD)
- Slug (kebab-case summary)
- Context, symptoms, root cause, fix, verification, notes
- Related pattern IDs (if any)

**For upstream pattern:**
- All front matter fields (see template above)
- Pattern type (troubleshooting/implementation/anti-pattern/architecture)
- Language, framework, domain
- Code examples (sanitized)
- Verification checklist

### Step 3: Generate File Content

**Use appropriate template:**
- Local case: Minimal front matter + 6 sections
- Upstream pattern: Full front matter + type-specific sections

**Apply sanitization:**
- Replace internal URLs with example.com
- Replace client names with generic terms
- Remove API keys and tokens
- Use generic class/model names
- Strip PII

### Step 4: Write File

**For local case:**
```bash
# File: .halo-halo/local/cases/2026-01-08-rails-viewcomponent-portal-disconnect.md
```

**For upstream pattern:**
```bash
# File: .halo-halo/halo-halo-upstream/patterns/ruby/rails/view_components/portal-disconnect-issue.md
```

### Step 5: Confirm with User

**Show:**
- File path
- Preview of content (first 50 lines)
- Sanitization applied

**Ask:**
```
I've created the pattern file at:
[file-path]

Preview:
[first 50 lines]

Sanitization applied:
- Replaced [specific items] with [placeholders]
- Removed [sensitive data types]

Ready to commit? Any changes needed?
```

---

## Constraints

- **Do not create files without Gatekeeper approval** - Writer executes, doesn't decide
- **Always sanitize** - No exceptions for upstream patterns
- **Use correct paths** - Local cases in .halo-halo/local/, upstream in submodule
- **Follow templates** - Local case has minimal front matter, upstream has full metadata
- **Ask before writing** - Confirm routing, path, and content structure first

---

## Example File Paths

**Local cases:**
```
.halo-halo/local/cases/2026-01-08-rails-query-n-plus-one.md
.halo-halo/local/cases/2026-01-08-nextjs-hydration-mismatch.md
.halo-halo/local/cases/2026-01-08-stimulus-controller-not-connecting.md
```

**Upstream patterns:**
```
.halo-halo/halo-halo-upstream/patterns/ruby/rails/active_record/n-plus-one-detection.md
.halo-halo/halo-halo-upstream/patterns/typescript/nextjs/server_actions/form-validation.md
.halo-halo/halo-halo-upstream/patterns/ruby/rails/view_components/portal-lifecycle.md
```

---

## Template References

**Local case template:**
```markdown
---
id: case-YYYYMMDD-001
date: YYYY-MM-DD
related_pattern_ids: []
resolution: success
---

# [Brief Title]

## Context

[What was being worked on, what led to the issue]

## Symptoms

[Observable behavior, error messages]

## Root Cause

[Technical explanation of why this happened]

## Fix Summary

[What was changed to resolve it]

## Verification

[How the fix was confirmed to work]

## Notes

[Additional observations, future considerations]
```

**Upstream pattern template (troubleshooting):**
```markdown
---
id: "pattern-ruby-rails-view-components-portal-disconnect"
title: "ViewComponent Stimulus Controller Not Connecting After Portal Move"
type: troubleshooting
status: draft
confidence: medium
revision: 1
languages:
  - language: ruby
    versions: ">=3.0"
frameworks:
  - name: rails
    versions: ">=7.0 <9.0"
  - name: view_component
    versions: ">=3.0"
dependencies:
  - name: shadcn-rails
    versions: ">=0.1"
domain: view_components
tags:
  - stimulus
  - portals
  - lifecycle
introduced: YYYY-MM-DD
last_verified: YYYY-MM-DD
review_by: YYYY-MM-DD
sanitized: true
related: []
---

# ViewComponent Stimulus Controller Not Connecting After Portal Move

## Context

[When does this happen? What are preconditions?]

## Symptoms

[Observable behavior, error messages]

## Root Cause

[Technical explanation]

## Fix

### Step 1: [Action]

```ruby
# Code example with comments
```

### Step 2: [Action]

```ruby
# More code
```

## Verification Checklist

- [ ] Controller connects in browser console
- [ ] Event handlers attached
- [ ] No JavaScript errors
- [ ] Works across different portal implementations

## Related Patterns

- pattern-ruby-rails-stimulus-controller-lifecycle
```

---

**Remember:** Writer executes Gatekeeper decisions. Sanitize everything. Ask before writing.

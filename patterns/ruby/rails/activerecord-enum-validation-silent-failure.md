---
id: "pattern-ruby-rails-activerecord-enum-validation-silent-failure"
title: "ActiveRecord Enum Validation Silent Failures"
type: troubleshooting
status: validated
confidence: high
revision: 1
languages:
  - language: ruby
    versions: ">=2.7"
frameworks:
  - name: rails
    versions: ">=6.0 <9.0"
dependencies: []
domain: active_record
tags:
  - enum
  - validation
  - silent-failure
  - data-persistence
introduced: 2026-01-08
last_verified: 2026-01-08
review_by: 2026-04-08
sanitized: true
related: []
---

# ActiveRecord Enum Validation Silent Failures

## Context

When using ActiveRecord enums, attempting to set an invalid enum value can fail silently without raising exceptions, leaving the record in an inconsistent state.

**Affected versions:** Rails 6.0+, Ruby 2.7+

**Common scenario:** Background jobs or async operations that set enum values based on string literals or external input.

## Symptoms

- Code appears to execute successfully (no exceptions raised)
- Database record's enum column remains unchanged
- Logs show operation completed
- No obvious error messages
- If using `update!`, may see cryptic validation errors in failed job logs
- Record appears "stuck" in old state

**Example:**
```ruby
# Job logs show "completed" but database unchanged
doc = Document.find(id)
doc.update!(status: "processing")  # "processing" not in enum
# → Validation error or silent failure depending on Rails version
```

## Root Cause

ActiveRecord enums are backed by integer columns with a predefined mapping. When you pass a string not in the enum definition:

1. **Rails 6.0-6.1:** Silent failure - value not set, no error raised
2. **Rails 7.0+:** Raises `ArgumentError` for invalid values with `update!`
3. **All versions:** `update` (without bang) silently fails validation

The mapping is defined at model level:

```ruby
class Document < ApplicationRecord
  enum status: {
    queued: 0,
    indexing: 1,
    completed: 2,
    failed: 3
  }
end

# These are invalid (not in enum):
doc.update!(status: "processing")  # ❌
doc.update!(status: "error")       # ❌
```

## Fix

**Prevention:** Always verify enum values before using them.

```ruby
# Check allowed values:
Document.statuses.keys
# => ["queued", "indexing", "completed", "failed"]

# Use symbols, not strings (catches typos at runtime):
doc.update!(status: :indexing)  # ✅

# Validate external input:
valid_statuses = Document.statuses.keys
if valid_statuses.include?(input_status)
  doc.update!(status: input_status)
else
  raise ArgumentError, "Invalid status: #{input_status}"
end
```

**Remediation:** Search codebase for invalid enum values.

```bash
# Find all enum definitions
grep -r "enum.*:" app/models/

# For each enum, search for hardcoded string literals
grep -r '"processing"' app/  # if "processing" not in enum
```

## Verification Checklist

- [ ] Run `Model.enum_attribute.keys` to list valid values
- [ ] Search codebase for string literals matching enum attribute
- [ ] Verify job/service code uses only valid enum values
- [ ] Check failed job logs for validation errors
- [ ] Add enum validation tests for edge cases

## Tradeoffs

**Using symbols vs strings:**
- Symbols catch typos at runtime (NoMethodError)
- Strings fail silently or via validation
- Trade-off: symbols are more verbose in some contexts

**Adding custom validation:**
```ruby
validates :status, inclusion: { in: statuses.keys }
```
This catches invalid values explicitly but adds overhead.

## References

- [ActiveRecord Enum Docs](https://api.rubyonrails.org/classes/ActiveRecord/Enum.html)
- Rails 7.0+ raises `ArgumentError` for invalid enum values (behavior change)

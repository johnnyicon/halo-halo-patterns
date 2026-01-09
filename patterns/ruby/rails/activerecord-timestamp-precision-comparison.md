---
id: "pattern-ruby-rails-activerecord-timestamp-precision-comparison"
title: "ActiveRecord Timestamp Precision in Comparisons"
type: troubleshooting
status: validated
confidence: high
revision: 1
languages:
  - language: ruby
    versions: ">=2.5"
frameworks:
  - name: rails
    versions: ">=5.0 <9.0"
dependencies: []
domain: active_record
tags:
  - timestamp
  - precision
  - comparison
  - microseconds
  - data-persistence
introduced: 2026-01-08
last_verified: 2026-01-08
review_by: 2026-04-08
sanitized: true
related: []
---

# ActiveRecord Timestamp Precision in Comparisons

## Context

When comparing timestamps (e.g., `last_processed_at >= updated_at`) to determine staleness or sync status, ActiveRecord's automatic `updated_at` handling can introduce microsecond-level differences that break comparisons.

**Affected versions:** Rails 5.0+, Ruby 2.5+

**Common scenario:** Sync flags, staleness checks, "needs reprocessing" logic based on timestamp comparisons.

## Symptoms

- Comparison method (e.g., `synced?`, `stale?`) always returns wrong value
- Timestamps appear identical when printed (to second precision)
- But comparison fails (`last_indexed_at >= updated_at` returns false)
- Database shows microsecond differences: `2026-01-08 15:54:27.123` vs `15:54:27.125`
- Issue intermittent or timing-dependent

**Example:**
```ruby
# Job sets last_indexed_at
doc.update!(last_indexed_at: Time.current, status: "completed")

# But synced? returns false
def synced?
  last_indexed_at.present? && last_indexed_at >= updated_at
end
# => false (because updated_at auto-set with NEW Time.current)
```

## Root Cause

`update!` and `update` automatically set `updated_at` to **a new `Time.current`** value, which will differ from any manually-set timestamp by microseconds.

```ruby
now = Time.current  # 2026-01-08 15:54:27.123456

doc.update!(
  last_indexed_at: now,
  status: "completed"
)

# What actually happens:
# last_indexed_at = 2026-01-08 15:54:27.123456 (your value)
# updated_at = 2026-01-08 15:54:27.125789 (Rails auto-set, NEW Time.current)

# Comparison fails:
doc.last_indexed_at >= doc.updated_at
# => false (123456 < 125789)
```

## Fix

**Use `update_columns` to bypass timestamp callbacks:**

```ruby
# ❌ WRONG - two different timestamps
doc.update!(
  last_indexed_at: Time.current,
  status: "completed"
)

# ✅ CORRECT - same timestamp for both
now = Time.current
doc.update_columns(
  last_indexed_at: now,
  updated_at: now,
  status: "completed"
)
```

**Caveat:** `update_columns` skips callbacks and validations. Only use when:
- You control the values (no validation needed)
- You explicitly want to bypass callbacks
- Timestamp precision matters for comparisons

**Alternative:** Add tolerance to comparison:

```ruby
def synced?
  return false unless last_indexed_at.present?
  
  # Allow 1-second tolerance
  (last_indexed_at - updated_at).abs < 1.second
end
```

This is less precise but avoids `update_columns`.

## Verification Checklist

- [ ] Identify all timestamp comparison logic in codebase
- [ ] Check if comparisons involve `updated_at` and manually-set timestamps
- [ ] Review usage of `update!` vs `update_columns` for sync operations
- [ ] Test comparison methods with fresh records (timestamps should match)
- [ ] Verify database timestamp precision (microseconds stored?)

## Tradeoffs

**Using `update_columns`:**
- ✅ Pro: Precise timestamp control
- ❌ Con: Skips validations and callbacks
- ❌ Con: Not transactionally safe (no rollback on error)

**Using tolerance in comparison:**
- ✅ Pro: Safer (doesn't skip validations)
- ❌ Con: Less precise (1-second window)
- ❌ Con: Doesn't fix root cause (timestamps still differ)

**Recommendation:** Use `update_columns` for sync/staleness operations where timestamp precision is critical and validation is not needed.

## References

- [ActiveRecord::Persistence#update_columns](https://api.rubyonrails.org/classes/ActiveRecord/Persistence.html#method-i-update_columns)
- [ActiveRecord Timestamp Callbacks](https://api.rubyonrails.org/classes/ActiveRecord/Timestamp.html)

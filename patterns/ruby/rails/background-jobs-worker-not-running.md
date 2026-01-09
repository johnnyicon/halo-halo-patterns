---
id: "pattern-ruby-rails-background-jobs-worker-not-running"
title: "Background Jobs Enqueued But Never Execute"
type: troubleshooting
status: validated
confidence: high
revision: 1
languages:
  - language: ruby
    versions: ">=3.0"
frameworks:
  - name: rails
    versions: ">=7.0 <9.0"
dependencies:
  - name: solid_queue
    versions: ">=0.1"
domain: background_jobs
tags:
  - queue
  - worker
  - solid_queue
  - silent-failure
  - async
introduced: 2026-01-08
last_verified: 2026-01-08
review_by: 2026-04-08
sanitized: true
related: []
---

# Background Jobs Enqueued But Never Execute

## Context

Background jobs are enqueued successfully but never execute, leaving features that depend on async processing stuck in "pending" or "processing" states indefinitely.

**Affected versions:** Rails 7.0+ with SolidQueue, or any background job system requiring separate worker processes

**Common scenario:** Developer starts web server only (`bin/rails s`) without starting job worker process.

**Note:** This pattern uses SolidQueue as the example, but applies to Sidekiq, Resque, or any background job system requiring separate worker processes.

## Symptoms

- Jobs enqueue successfully (confirmed in database or Redis)
- No errors in application logs
- Features depending on jobs appear "stuck" or never complete
- Spinners spin indefinitely
- Status never changes from "queued" or "processing"
- Database shows jobs with `finished_at: nil` and `ready: true`

**Example (SolidQueue):**
```ruby
# Controller enqueues job successfully
ProcessDocumentJob.perform_later(doc_id: doc.id)
# => Job ID 335 created

# But checking status:
SolidQueue::Job.find(335).finished_at
# => nil (never executed)

SolidQueue::ReadyExecution.count
# => 1 (ready to run, but no worker to claim it)
```

## Root Cause

**The job worker process is not running.**

Most background job systems require **two separate processes**:
1. **Web server** - handles HTTP requests, enqueues jobs
2. **Worker process** - claims and executes jobs from queue

Starting only the web server means jobs queue but never execute.

**SolidQueue example:**
```bash
# ❌ WRONG - only starts web server
bin/rails s

# ✅ CORRECT - starts web + worker
foreman start -f Procfile.dev
# OR start separately:
# Terminal 1: bin/rails s
# Terminal 2: bin/jobs
```

**Procfile.dev:**
```
web: bin/rails s
vite: bin/vite dev
jobs: bin/jobs    # ← Worker process
```

## Fix

**Immediate fix:** Start the worker process.

```bash
# Check if worker is running (SolidQueue):
bin/rails runner 'puts "Workers: #{SolidQueue::Process.count}"'
# => 0 (no workers)

# Start worker:
cd apps/<your-app> && bin/jobs
# OR use foreman:
cd apps/<your-app> && foreman start -f Procfile.dev
```

**Prevention:** Update development setup documentation to always start both processes.

**Diagnostic script (SolidQueue):**
```ruby
# Save as bin/jobs-health-check
#!/usr/bin/env ruby
require_relative "../config/environment"

puts "=== BACKGROUND JOBS HEALTH CHECK ==="
workers = SolidQueue::Process.count
pending = SolidQueue::Job.where(finished_at: nil).count
ready = SolidQueue::ReadyExecution.count

puts "Active workers: #{workers}"
puts "Pending jobs: #{pending}"
puts "Ready to execute: #{ready}"
puts ""

if workers == 0 && ready > 0
  puts "🔴 PROBLEM: No workers running, but #{ready} jobs ready"
  puts "   FIX: Start workers with: bin/jobs or foreman start"
elsif workers > 0 && ready > 0
  puts "🟡 WARNING: Workers running but jobs not being claimed"
  puts "   Check worker logs for errors"
elsif pending == 0
  puts "🟢 All jobs processed"
else
  puts "🟡 Jobs pending but not ready - check scheduled_at"
end
```

**Generalized check (framework-agnostic):**
```bash
# Check if job worker process is running
ps aux | grep -E "sidekiq|jobs|worker|resque" | grep -v grep
# Should show at least one worker process
```

## Verification Checklist

- [ ] Check worker process count (`SolidQueue::Process.count` or equivalent)
- [ ] Verify `Procfile.dev` includes worker process definition
- [ ] Confirm dev setup docs mention starting workers
- [ ] Add health check script to bin/ directory
- [ ] Test job execution after starting worker
- [ ] Monitor worker logs for errors

## Tradeoffs

**Foreman vs separate terminals:**
- Foreman: One command, all processes together, easier to kill all
- Separate: Can restart individual processes, easier to see specific logs

**Recommendation:** Use Foreman for development (simpler), separate processes for debugging specific worker issues.

**Process management in production:**
- Use systemd, supervisord, or container orchestration
- Ensure worker processes have auto-restart
- Monitor worker count with alerting
- Set up health check endpoints

## References

- [SolidQueue Documentation](https://github.com/basecamp/solid_queue)
- [Sidekiq Getting Started](https://github.com/sidekiq/sidekiq/wiki/Getting-Started)
- [Foreman Procfile Format](https://ddollar.github.io/foreman/)
- [Process Management Best Practices](https://12factor.net/processes)

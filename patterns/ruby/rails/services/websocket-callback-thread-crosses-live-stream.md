---
id: "pattern-ruby-rails-websocket-callback-thread-crosses-live-stream"
title: "WebSocket Callback Thread Crosses ActionController::Live Stream"
type: troubleshooting
status: validated
confidence: high
revision: 1
languages:
  - language: ruby
    versions: ">=3.0"
frameworks:
  - name: rails
    versions: ">=7.0"
dependencies:
  - websocket-client-simple
  - faye-websocket
domain: streaming
tags:
  - websocket
  - sse
  - actioncontroller-live
  - threading
  - stream-closed
  - daemon-bridge
introduced: 2026-02-25
last_verified: 2026-02-25
review_by: 2026-05-25
sanitized: true
related: []
---

# WebSocket Callback Thread Crosses ActionController::Live Stream

## Context

When a Rails controller uses `ActionController::Live` to stream SSE responses, the `response.stream` object must only be written from the thread that owns the request. Many Ruby WebSocket client gems (`websocket-client-simple`, `faye-websocket`) fire `on :message` callbacks on a **background reactor/EM thread**, not the controller thread.

If you yield or write to `response.stream` directly from a WS callback, you get a cross-thread write that either silently fails, corrupts the stream, or raises an error.

**Affected gems:** `websocket-client-simple`, `faye-websocket`, any EventMachine-based WS client.

**Common scenario:** Rails acts as a bridge — browser connects via SSE, Rails connects to an upstream WebSocket service, and translates WS events into SSE events.

## Symptoms

- **"stream closed in another thread"** error appears in the browser or Rails logs
- Streamed content (deltas, tool calls) appears briefly then vanishes
- Partial responses are lost — the assistant message never gets persisted
- Intermittent: works sometimes (when WS responses are fast enough), fails under load or with longer responses
- The SSE connection drops mid-stream with no clear server-side exception

**Error message:**
```
Daemon connection error: stream closed in another thread
```

## Root Cause

```
┌──────────────────────┐     ┌──────────────────────┐
│  Controller Thread   │     │  WS Reactor Thread   │
│  (owns response.stream)│   │  (EM / background)   │
│                      │     │                      │
│  bridge.stream(msg)  │     │  ws.on(:message) {   │
│    │                 │     │    yield(event_type,  │
│    │  sleep 0.1      │     │      event_data)     │
│    │  (polling)      │     │  }                   │
│                      │     │    ↓                  │
│                      │     │  response.stream.write│ ← CROSS-THREAD!
└──────────────────────┘     └──────────────────────┘
```

The `yield` from inside a WS callback executes the block (which writes to `response.stream`) on the **callback thread**, not the controller thread. Rails' Live stream is not thread-safe for writes from arbitrary threads.

Additionally:
- `sleep 0.1` as a "wait for connection" is a race condition — the WS handshake may not be complete
- When the WS closes, there's a race between the close handler setting a done flag and pending callback writes

## Solution: Thread-Safe Queue Pattern

Decouple the WS callbacks from the SSE writer using a `Queue`:

```ruby
class DaemonBridge
  DONE = :done

  def initialize(...)
    @events = Queue.new  # Thread-safe: WS pushes, controller pops
    # ...
  end

  def stream(content, &block)
    ws = connect_ws
    wait_for_open(ws, timeout: 5)  # Proper latch, not sleep

    ws.send(build_chat_message(content).to_json)

    # Drain on the CONTROLLER thread — only thread that writes SSE
    drain_events(&block)

    ws.close rescue nil
    { content: @content, error: @error }
  end

  private

  def connect_ws
    ws = WebSocket::Client::Simple.connect(DAEMON_URL)
    open_latch = Queue.new

    ws.on(:open)    { open_latch.push(:open) }
    ws.on(:message) { |msg| enqueue_ws_message(msg.data) }
    ws.on(:error)   { |e| enqueue_error(e) }
    ws.on(:close)   { enqueue_done }

    @open_latch = open_latch
    ws
  end

  def wait_for_open(ws, timeout: 5)
    thread = Thread.new { @open_latch.pop }
    thread.join(timeout) || (thread.kill; raise "WS connection timeout")
  end

  # WS callbacks push events (background thread)
  def enqueue_ws_message(raw_data)
    parsed = JSON.parse(raw_data)
    event = translate(parsed)       # → ["delta", envelope_hash]
    @events.push(event) if event
  end

  def enqueue_error(e)
    @events.push(["run_error", build_error_envelope(e.message)])
    @events.push(DONE)
  end

  def enqueue_done
    @events.push(DONE)
  end

  # Controller thread drains (blocking pop)
  def drain_events
    loop do
      event = @events.pop           # blocks until available
      break if event == DONE
      yield(*event)                  # writes SSE on controller thread ✓
    end
  end
end
```

### Key principles

1. **WS callbacks only push to Queue** — never yield, never write to stream
2. **Controller thread only pops from Queue** — it's the sole SSE writer
3. **Use a latch for connection readiness** — not `sleep`
4. **DONE sentinel terminates the drain loop** — clean shutdown

### Also fix: persist before signaling completion

If the SSE client clears streamed content on `run_completed` and refetches from the DB, ensure the assistant message is persisted **before** sending `run_completed`:

```ruby
# ✅ Persist first
session.messages.create!(role: "assistant", content: result[:content], run_id: run_id)
# Then update run status
pending_run.update!(status: "completed", ...)

# ❌ Don't do this — race condition
pending_run.update!(status: "completed", ...)
# Client refetches here, finds nothing
session.messages.create!(...)  # too late
```

## Architectural Alternatives

| Approach | Complexity | Thread Safety |
|----------|-----------|---------------|
| **Queue pattern** (above) | Low — works with any WS gem | ✅ Controller thread writes SSE |
| **async-websocket** (fiber-based) | Medium — new dependency ecosystem | ✅ Fibers, no cross-thread |
| **websocket-driver + TCPSocket** | Medium — ~50 LOC custom client | ✅ Synchronous reads on controller thread |
| **Separate process + Redis pub/sub** | High — new infra | ✅ Full decoupling |

The Queue pattern is the simplest fix that works with any gem. For a longer-term solution, consider `async-websocket` or a thin `websocket-driver` wrapper for synchronous reads.

## Prevention

- **Never yield or write to `response.stream` from a callback thread.** Always use a queue or channel to hand data back to the controller thread.
- **Never use `sleep` to wait for connection readiness.** Use a latch (`Queue`, `ConditionVariable`, or `Async::Condition`).
- **Always persist data before sending completion signals** when clients will refetch from the DB on completion.

## References

- [Rails ActionController::Live docs](https://api.rubyonrails.org/classes/ActionController/Live.html)
- [websocket-client-simple threading](https://github.com/shokai/websocket-client-simple)
- Ruby `Queue` (stdlib) — thread-safe, blocking `.pop`

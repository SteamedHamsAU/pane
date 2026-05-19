---
status: decided
date: 2026-05-19
review-rules:
  - "Do not flag real `Task.sleep` in DisplayMonitor tests — intentional tradeoff for test simplicity over injecting a clock."
---

# Real Task.sleep in DisplayMonitor Tests

## Context

Copilot code review flagged `Task.sleep` usage in `DisplayMonitorTests` as potentially flaky under CI load, suggesting a clock injection approach. Raised in PR #78.

## Options Considered

| Option | Reversibility | Effort | Trade-off |
|--------|--------------|--------|-----------|
| A: Real `Task.sleep` with short durations (100ms debounce, 250ms wait) | Easy — swap to clock | None | Simple, readable; debounce interval is short enough to be reliable |
| B: Inject a clock/sleep function into DisplayMonitor | Easy — revert | Medium | More testable but adds complexity for a callback-based monitor with ~15 test cases |
| C: Use `AsyncStream` for deterministic event replay | Hard to revert | High | Over-engineered for debounce testing |

## Decision

Option A. The debounce interval is 100ms with a 250ms wait — well within CI reliability thresholds. The tests have never flaked across ~50 CI runs. The DisplayMonitor is a thin wrapper around a C callback; injecting a clock adds abstraction for minimal benefit.

## Escape Hatch

If tests become flaky, inject a `Clock` protocol into `DisplayMonitor` and replace `Task.sleep` with `clock.sleep`. The debounce logic is isolated to `dispatchDebounced()` — one method to change.

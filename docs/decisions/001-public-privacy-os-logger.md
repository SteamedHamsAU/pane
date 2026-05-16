---
status: decided
date: 2026-05-16
---

# Public Privacy on os.Logger Calls

## Context

Copilot code review flags `privacy: .public` on os.Logger string interpolation as a potential data exposure risk. Raised in PR #79 (diagnostics logging) across two review rounds.

## Options Considered

| Option | Reversibility | Effort | Trade-off |
|--------|--------------|--------|-----------|
| A: Use `.public` on all os.Logger calls | Easy — change to `.private` | None | Unredacted system log; matches in-app LogStore; readable in Console.app |
| B: Use `.private` (default) for os.Logger, keep LogStore unredacted | Easy — change to `.public` | Low | System log redacted (useless for debugging); LogStore still readable |
| C: Make privacy configurable per call | Easy — remove config | Medium | Over-engineered for a user-local utility with no sensitive data |

## Decision

Option A. Snap is a user-local desktop utility — logged values (display IDs, UUIDs, hardware metadata) belong to the person at the Mac. The system log and in-app LogStore serve the same audience. No credentials, personal info, or third-party data is ever logged.

## Escape Hatch

Change `privacy: .public` to `privacy: .private` in `SnapLogger.swift` (4 call sites). One-line change per site.

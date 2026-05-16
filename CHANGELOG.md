# Changelog

All notable changes to Snap will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.4.0-beta] — 2026-05-16

### Added

- In-app diagnostics logging with ring buffer and new Settings → Diagnostics tab — filter by category/level, auto-refresh, clipboard export ([#79])
- `SnapLogger` dual-write logger: messages go to both `os.Logger` (Console.app) and the in-app ring buffer
- Architecture Decision Records in `docs/decisions/` with template and index
- ADR-001: documents intentional `privacy: .public` on os.Logger calls
- Copilot code review instructions in `.github/copilot-instructions.md`

### Changed

- All logging switched from `os.Logger` to `SnapLogger` across AppDelegate, DisplayMonitor, DisplayConfigurator, DisplayConfigStore, and ToastWindowController
- DisplayMonitor display lookup functions (UUID, name, bounds) are now injectable for test isolation
- DiagnosticsView uses SwiftUI `.task` modifier with generation-counter optimization
- `LogStore.Level`, `LogStore.Entry`, and `SnapLogger` now explicitly declare `Sendable`

### Fixed

- Cancel pending debounce tasks on `stopMonitoring()` to prevent stale delegate calls after shutdown ([#80])
- Implicit strong `self` capture in `[weak self]` Task closure in AppDelegate toast handler
- Stale category filter in DiagnosticsView after ring buffer eviction or clear
- Uncancelled auto-dismiss Task in ToastWindowController — now stored and cancelled on `show()`/`dismiss()`
- `print()` in SettingsView error path replaced with `SnapLogger`
- `launchAtLogin` toggle now reads `SMAppService` status in `.onAppear` instead of at struct init

## [0.3.3-alpha] — 2026-05-12

### Fixed

- Extend re-apply failed when display was already unmirrored — no-op unmirror transaction is now skipped, so positioning always runs ([#87])

## [0.3.2-alpha] — 2026-04-28

### Fixed

- External Above preset left-aligned instead of centred when transitioning from mirror mode — display bounds are now read after the unmirror transaction commits ([#85])

## [0.3.1-alpha] — 2026-04-28

### Fixed

- False "No display connected" after applying mirror or extend configuration — macOS reconfiguration events with both `removeFlag` and `addFlag` are now correctly treated as no-ops instead of disconnects ([#83])

## [0.3.0-alpha] — 2026-04-09

### Added

- Display hardening: resilient display detection with UUID-based identification, retry logic, and graceful fallbacks ([#78])
- Debug details panel in Settings → Displays (Option-click the tab to toggle) ([#78])
- Comprehensive test suite: `DisplayConfigStore`, `DisplayConfigurator`, `DisplayMonitor` tests ([#78])
- Auto-dispatch appcast update to website repo on tagged release ([#77])
- CI environment gate (`website-deploy`) for website dispatch ([#77])

### Fixed

- Option-click debug toggle now scoped to tab-switch gesture only — no longer triggers on any Option-click in the window ([#78])
- Test host no longer launches full UI, preventing CI hangs ([#78])

## [0.2.1-alpha] — 2026-03-26

### Fixed

- Release build errors under Swift 6 strict concurrency (`-O` optimisation level) ([#72])
- SwiftFormat/SwiftLint `nonisolated` modifier order conflict ([#72])

### Changed

- Integrated branding assets (app icon, menu bar icon) into build ([#72])

## [0.2.0-alpha] — 2026-03-24

### Added

- Display detection at launch via `CGDisplayRegisterReconfigurationCallback` ([#53])
- Build number generation from Git commit count (`Scripts/set-build-number.sh`) ([#55])
- Release workflow: archive, DMG, Sparkle signing, GitHub Release ([#73])
- Branding assets: icon candidates, menu bar icons, prompt renders

### Changed

- Renamed project from Pane to Snap ([#69])
- Rewrote README with user-focused structure

[0.3.3-alpha]: https://github.com/SteamedHamsAU/snap/compare/v0.3.2-alpha...v0.3.3-alpha
[0.3.2-alpha]: https://github.com/SteamedHamsAU/snap/compare/v0.3.1-alpha...v0.3.2-alpha
[0.3.1-alpha]: https://github.com/SteamedHamsAU/snap/compare/v0.3.0-alpha...v0.3.1-alpha
[0.3.0-alpha]: https://github.com/SteamedHamsAU/snap/compare/v0.2.1-alpha...v0.3.0-alpha
[0.2.1-alpha]: https://github.com/SteamedHamsAU/snap/compare/v0.2.0-alpha...v0.2.1-alpha
[0.2.0-alpha]: https://github.com/SteamedHamsAU/snap/releases/tag/v0.2.0-alpha

[#53]: https://github.com/SteamedHamsAU/snap/pull/53
[#55]: https://github.com/SteamedHamsAU/snap/pull/55
[#69]: https://github.com/SteamedHamsAU/snap/pull/69
[#72]: https://github.com/SteamedHamsAU/snap/pull/72
[#73]: https://github.com/SteamedHamsAU/snap/pull/73
[#77]: https://github.com/SteamedHamsAU/snap/pull/77
[#87]: https://github.com/SteamedHamsAU/snap/pull/87
[#85]: https://github.com/SteamedHamsAU/snap/pull/85
[#83]: https://github.com/SteamedHamsAU/snap/pull/83
[#78]: https://github.com/SteamedHamsAU/snap/pull/78

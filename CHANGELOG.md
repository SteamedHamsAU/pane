# Changelog

All notable changes to Snap will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

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

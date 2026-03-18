# Pane

A macOS menu bar utility that automatically manages your display arrangement when you plug in an external monitor.

No more digging through System Settings every time you dock your MacBook.

## How It Works

1. **Plug in a monitor** — Pane detects it instantly (even if it was already connected at launch)
2. **Choose your layout** — a floating prompt lets you pick Extend (right, left, or above) or Mirror mode
3. **Optionally remember it** — next time that monitor connects, Pane applies your saved layout silently and shows a brief toast confirmation

That's it. Pane lives in your menu bar, stays out of the way, and does the one thing macOS should do natively.

## Features

- **Instant detection** — recognises displays on connection and at app launch
- **Extend or Mirror** — visual preset diagrams so you know exactly what you're choosing
- **Per-display memory** — remembers configurations by display UUID; different monitors get different layouts
- **Rich display info** — shows display name, screen size, and native resolution (e.g. "DELL U2723QE 27″ 3840 × 2160")
- **Toast notifications** — brief confirmation when a saved config is auto-applied, with a "Change" action to re-prompt
- **Launch at login** — set it and forget it
- **Menu bar** — current display status, quick access to remembered displays, settings
- **Auto-updates** — built-in update checking via Sparkle

## Requirements

- macOS 15 (Sequoia) or later
- Apple Silicon or Intel Mac

## Install

> Releases coming soon. For now, build from source.

### From Source

```bash
brew install xcodegen swiftformat swiftlint xcbeautify
git clone https://github.com/SteamedHamsAU/pane.git
cd pane
./Scripts/bootstrap.sh
```

Or manually:

```bash
xcodegen generate
xcodebuild build -scheme Pane -destination 'platform=macOS' CODE_SIGN_IDENTITY="-"
```

The built app lands in Xcode's DerivedData. Open `Pane.xcodeproj` in Xcode to set your Team ID under Signing & Capabilities for a signed build.

## Settings

- **General** — launch at login, notification toggle
- **Displays** — view and forget remembered monitors
- **About** — version info, license, check for updates

## Contributing

Pull requests run CI on `macos-15` runners: SwiftFormat → SwiftLint → Build → Test.

### Architecture

```
Sources/Pane/
├── App/            — Entry point, AppDelegate, Info.plist
├── Display/        — Display monitoring, configuration, persistence
├── UI/             — Window controllers (Prompt, Toast, MenuBar, Settings)
├── Views/          — SwiftUI views hosted in AppKit windows
└── Extensions/     — Type extensions
```

- **AppKit + SwiftUI hybrid** — NSPanel/NSStatusItem for windowing, SwiftUI for view content
- **Swift 6** with strict concurrency (`SWIFT_STRICT_CONCURRENCY = complete`)
- **Unsandboxed** — requires CGDisplay and IOKit APIs for display arrangement
- **Persistence** — per-display configs in `~/Library/Application Support/Pane/displays.plist`
- **Direct distribution** with Sparkle 2 auto-updates (no App Store)

## License

Pane is released under the [MIT License](LICENSE).

Copyright (c) 2026 Steamed Hams Pty Ltd

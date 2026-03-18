# Pane

A macOS menu bar utility that manages display arrangements when external monitors connect.

Pane intercepts display connection events and presents a focused prompt to choose between Extend and Mirror modes, select an arrangement preset, and optionally save the configuration. On subsequent connections of a known display, Pane silently applies the saved config and shows a brief toast notification.

## Features

- **Auto-detect external displays** — prompts immediately when a new monitor connects
- **Extend mode** — arrange the external display to the right, left, or above your MacBook, with visual preset diagrams
- **Mirror mode** — optimise for MacBook or external resolution
- **Remember displays** — save per-display configurations by UUID; known displays auto-apply silently on reconnect
- **Rich display info** — shows display name, screen size, and native resolution (e.g. "DELL U2723QE 27″ 3840 × 2160")
- **Toast notifications** — brief confirmation when a saved config is applied, with a "Change" action to re-prompt
- **Settings window** — General (launch at login, notification toggle), Displays (list/forget remembered monitors), About (version, license, update check)
- **Menu bar** — status icon with current display state, remembered displays submenu, and Option-key developer items (re-trigger prompt, test notification)
- **Sparkle auto-updates** — direct distribution with built-in update checking

## Requirements

- macOS 15 (Sequoia) or later
- Universal binary (Apple Silicon + Intel)

## Building

### Prerequisites

```bash
brew install xcodegen swiftformat swiftlint xcbeautify
```

### Quick Start

```bash
git clone https://github.com/SteamedHamsAU/pane.git
cd pane
./Scripts/bootstrap.sh
```

### Manual Build

```bash
xcodegen generate
xcodebuild build -scheme Pane -destination 'platform=macOS' CODE_SIGN_IDENTITY="-"
```

Open `Pane.xcodeproj` in Xcode once to set your Team ID under Signing & Capabilities.

## CI/CD

Pull requests run **CI** on `macos-15` runners:
- `xcodegen generate` → SwiftFormat lint → SwiftLint → Build → Test

Merges to `main` run a **post-merge build** to catch integration issues.

Tagged releases (`v*`) trigger a **release workflow** that builds, archives, notarises, and publishes a GitHub Release with the `.dmg`.

## Architecture

```
Sources/Pane/
├── App/            — Entry point, AppDelegate, Info.plist
├── Display/        — Display monitoring, configuration model, persistence, application
├── UI/             — Window controllers (Prompt, Toast, MenuBar, Settings)
├── Views/          — SwiftUI views hosted in AppKit windows
└── Extensions/     — Type extensions
```

- **AppKit + SwiftUI hybrid** — NSPanel/NSStatusItem for windowing, SwiftUI for view content
- **Swift 6** with strict concurrency (`SWIFT_STRICT_CONCURRENCY = complete`)
- **No sandbox** — requires CGDisplay and IOKit APIs for display arrangement
- **Direct distribution** with Sparkle 2 auto-updates
- **Persistence** — per-display configs in `~/Library/Application Support/Pane/displays.plist`, preferences in UserDefaults

## Distribution

Direct download with Sparkle auto-updates. No App Store — the app runs unsandboxed for CGDisplay and IOKit access.

## License

Pane is released under the [MIT License](LICENSE).

Copyright (c) 2026 Steamed Hams Pty Ltd

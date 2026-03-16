# Pane

A macOS menu bar utility that manages display arrangements when external monitors connect.

Pane intercepts display connection events and presents a focused prompt to choose between Extend and Mirror modes, select an arrangement preset, and optionally save the configuration. On subsequent connections of a known display, Pane silently applies the saved config and shows a brief toast notification.

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
- **Swift 6** with strict concurrency
- **No sandbox** — requires CGDisplay and IOKit APIs
- **Direct distribution** with Sparkle 2 auto-updates

## Distribution

Direct download with Sparkle auto-updates.

## License

Pane is released under the [MIT License](LICENSE).

Copyright (c) 2026 Steamed Hams Pty Ltd

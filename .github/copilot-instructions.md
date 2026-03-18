# Copilot Instructions — Pane

## Platform & Language
- macOS 15+ only. No iOS, watchOS, or widget targets.
- Swift 6 with strict concurrency throughout (`SWIFT_STRICT_CONCURRENCY = complete`).
- All async code uses Swift Concurrency: async/await, actors, structured concurrency.
- Universal binary: Apple Silicon + Intel (`arm64 x86_64`).

## Architecture
- AppKit + SwiftUI hybrid. The app uses `NSApplicationDelegate`, `NSStatusItem`, `NSPanel`, and `NSHostingView` to host SwiftUI views.
- No pure SwiftUI `@main App` lifecycle — the entry point is `PaneApp.swift` using `@main` with `NSApplicationMain`.
- Mark all UI and display-related code `@MainActor`.
- Business logic in `Display/` directory as structs or actors.
- No singletons. Dependency injection via initialiser parameters or `@Environment`.

## Display APIs
- Use `CGDisplayRegisterReconfigurationCallback` for display connect/disconnect detection.
- Use `CGBeginDisplayConfiguration` / `CGConfigureDisplayOrigin` / `CGConfigureDisplayMirrorOfDisplay` / `CGCompleteDisplayConfiguration` for applying display arrangements.
- Use `IOKit` to query display product names via `IODisplayConnect`.
- Use `CGDisplayCreateUUIDRef` for persistent display identification.
- All CGDisplay API calls are synchronous and safe to call from `@MainActor`.
- The reconfiguration callback arrives on an arbitrary thread — always dispatch to `@MainActor` before touching UI or state.

## UI Patterns
- `NSPanel` with `nonactivatingPanel` style mask for the prompt window (doesn't steal focus).
- `NSStatusItem` with template image for the menu bar icon.
- SwiftUI views hosted inside `NSHostingView` for all panel/window content.
- Toast notifications use borderless `NSPanel` with `level = .floating`.
- Use SwiftUI `Canvas` for preset diagrams (not image assets).

## Persistence
- `DisplayConfigStore` persists to `~/Library/Application Support/Pane/displays.plist`.
- Keyed by display UUID string from `CGDisplayCreateUUIDRef`.
- Last-used presets stored in `UserDefaults` (`lastExtendPreset`, `lastMirrorTarget`).
- No SwiftData, no CoreData, no CloudKit.

## Code Style
- Prefer structs and enums over classes.
- Use `@Observable` macro for any observable state (not `ObservableObject`).
- Extensions in separate files: `Type+Domain.swift`.
- No force unwraps. Use `guard let`, `if let`, or `?? default`.
- Error handling: `throws` / `try-catch`. Not `Result<>` unless required by callback APIs.
- No Combine. Use `AsyncStream` or `AsyncSequence` instead.
- No `DispatchQueue` except for the CGDisplay callback bridge. Use actors and `async/await` everywhere else.

## What to Avoid
- No third-party UI frameworks. SwiftUI + AppKit only.
- No singleton pattern.
- No `@EnvironmentObject` or `@Published`.
- No `ObservableObject`.
- No App Store sandboxing — the app runs unsandboxed for CGDisplay and IOKit access.

## Distribution
- Direct download, not App Store.
- Sparkle 2 for auto-updates (SPM dependency).
- `LSUIElement = true` — menu bar only, no Dock icon.

## Testing
- Swift Testing framework for all new tests (not XCTest).
- Mock display APIs via protocols for unit testing.
- Test `DisplayConfigStore` with temporary file paths.
- Test `DisplayConfiguration` model encoding/decoding.

## File Naming
- Controllers: `FeatureNameWindowController.swift`
- Views: `FeatureNameView.swift`
- Models: `ModelName.swift`
- Services/Monitors: `DomainMonitor.swift`, `DomainStore.swift`
- Extensions: `Type+Domain.swift`

## Build & Run

After making code changes, always build and verify. Kill existing instances before re-launching.

```bash
# Regenerate Xcode project from project.yml (if project.yml changed)
xcodegen generate

# Build
xcodebuild -project Pane.xcodeproj -scheme Pane -configuration Debug build

# Run (kill existing first)
pkill -x Pane 2>/dev/null; sleep 0.5
open "$(xcodebuild -project Pane.xcodeproj -scheme Pane -configuration Debug -showBuildSettings 2>/dev/null | grep ' BUILT_PRODUCTS_DIR' | awk '{print $3}')/Pane.app"

# Tests
xcodebuild -project Pane.xcodeproj -scheme Pane -configuration Debug test
```

For display-related changes, remind Luke to plug/unplug an external display to test detection.

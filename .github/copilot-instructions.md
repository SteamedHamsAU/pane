# Copilot Instructions — Snap

## Platform & Language
- macOS 15+ only. No iOS, watchOS, or widget targets.
- Swift 6 with strict concurrency throughout (`SWIFT_STRICT_CONCURRENCY = complete`).
- All async code uses Swift Concurrency: async/await, actors, structured concurrency.
- Universal binary: Apple Silicon + Intel (`arm64 x86_64`).

## Code Review
Design decisions are documented as ADRs in `docs/decisions/`. Each ADR may include
a `review-rules` list in its YAML front matter — these are extracted into
`.github/instructions/code-review.instructions.md` by `Scripts/generate-review-instructions.sh`.

Run the generator after adding or updating an ADR:
```bash
Scripts/generate-review-instructions.sh        # regenerate
Scripts/generate-review-instructions.sh --check # verify freshness (CI)
```

## Architecture
- AppKit + SwiftUI hybrid. The app uses `NSApplicationDelegate`, `NSStatusItem`, `NSPanel`, and `NSHostingView` to host SwiftUI views.
- No pure SwiftUI `@main App` lifecycle — the entry point is `SnapApp.swift` using `@main` with a custom `static func main()` that calls `NSApplication.shared.run()`.
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
- `DisplayConfigStore` persists to `~/Library/Application Support/Snap/displays.plist`.
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

```bash
xcodegen generate  # only if project.yml changed
xcodebuild -project Snap.xcodeproj -scheme Snap -configuration Debug build
xcodebuild -project Snap.xcodeproj -scheme Snap -configuration Debug test
```

For display changes, test with external display plug/unplug.

# Static Review Rules — Snap

These rules apply to all code reviews. They reflect project conventions
documented in `.github/copilot-instructions.md` and architecture decisions
in `docs/decisions/`.

## Language & Concurrency

- Swift 6 with strict concurrency (`SWIFT_STRICT_CONCURRENCY = complete`). Do not weaken concurrency checking.
- All async code must use Swift Concurrency (async/await, actors, structured concurrency). No Combine, no `DispatchQueue` except for the `CGDisplayRegisterReconfigurationCallback` bridge.
- Mark all UI and display-related code `@MainActor`.

## Architecture

- AppKit + SwiftUI hybrid via `NSHostingView`. No pure SwiftUI `@main App` lifecycle.
- No singletons. Dependency injection via initialiser parameters or `@Environment`.
- Use `@Observable` macro for observable state. Do not use `ObservableObject`, `@Published`, or `@EnvironmentObject`.
- Prefer structs and enums over classes.

## Error Handling & Safety

- No force unwraps. Use `guard let`, `if let`, or `?? default`.
- Error handling via `throws` / `try-catch`. Not `Result<>` unless required by callback APIs.
- No third-party UI frameworks — SwiftUI + AppKit only.

## Testing

- All new tests use Swift Testing framework (`import Testing`, `@Test`, `#expect`). Do not use XCTest for new tests.
- Mock display APIs via protocols (e.g. `DisplayTransacting`) for unit testing.
- Do not flag `import Foundation` as unused in test files — Swift Testing may require it implicitly.
- Notification permission callbacks already dispatch to `@MainActor` before updating state. Do not flag the outer callback closure for actor isolation.

## Distribution & Sandboxing

- App runs unsandboxed for CGDisplay and IOKit access. Do not add App Store sandbox entitlements.
- `LSUIElement = true` — menu bar only, no Dock icon.

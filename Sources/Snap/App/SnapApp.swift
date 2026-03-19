import AppKit

/// App entry point. Snap is a menu-bar-only app (LSUIElement = true).
@main
struct SnapApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

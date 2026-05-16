import Foundation
import os

/// Dual-write logger that sends messages to both `os.Logger` (system console)
/// and the in-app `LogStore` ring buffer for diagnostics.
///
/// Drop-in replacement for `os.Logger` — same method names, takes `String`
/// instead of `OSLogMessage` so interpolated values are captured without
/// redaction.
///
/// Messages are logged with `privacy: .public` because Snap is a user-local
/// desktop utility — logged values (display IDs, UUIDs, paths) are the user's
/// own hardware metadata, not sensitive data. The in-app LogStore and system
/// log serve the same audience: the person sitting at the Mac.
struct SnapLogger {
    private let osLogger: Logger
    private let category: String
    private let logStore: LogStore

    init(category: String, logStore: LogStore) {
        self.osLogger = Logger(
            subsystem: Bundle.main.bundleIdentifier ?? "au.steamedhams.snap",
            category: category
        )
        self.category = category
        self.logStore = logStore
    }

    func info(_ message: String) {
        osLogger.info("\(message, privacy: .public)")
        logStore.append(level: .info, category: category, message: message)
    }

    func notice(_ message: String) {
        osLogger.notice("\(message, privacy: .public)")
        logStore.append(level: .notice, category: category, message: message)
    }

    func warning(_ message: String) {
        osLogger.warning("\(message, privacy: .public)")
        logStore.append(level: .warning, category: category, message: message)
    }

    func error(_ message: String) {
        osLogger.error("\(message, privacy: .public)")
        logStore.append(level: .error, category: category, message: message)
    }
}

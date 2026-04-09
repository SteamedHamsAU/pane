import Foundation
import os

/// Dual-write logger that sends messages to both `os.Logger` (system console)
/// and the in-app `LogStore` ring buffer for diagnostics.
///
/// Drop-in replacement for `os.Logger` — same method names, takes `String`
/// instead of `OSLogMessage` so interpolated values are captured without
/// redaction.
struct SnapLogger {
    private let osLogger: Logger
    private let category: String

    init(category: String) {
        self.osLogger = Logger(
            subsystem: Bundle.main.bundleIdentifier ?? "au.steamedhams.snap",
            category: category
        )
        self.category = category
    }

    func info(_ message: String) {
        osLogger.info("\(message, privacy: .public)")
        LogStore.shared.append(level: .info, category: category, message: message)
    }

    func notice(_ message: String) {
        osLogger.notice("\(message, privacy: .public)")
        LogStore.shared.append(level: .notice, category: category, message: message)
    }

    func warning(_ message: String) {
        osLogger.warning("\(message, privacy: .public)")
        LogStore.shared.append(level: .warning, category: category, message: message)
    }

    func error(_ message: String) {
        osLogger.error("\(message, privacy: .public)")
        LogStore.shared.append(level: .error, category: category, message: message)
    }
}

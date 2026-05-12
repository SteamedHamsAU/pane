import Foundation
import os

/// Thread-safe in-memory ring buffer for diagnostic log entries.
///
/// Uses `OSAllocatedUnfairLock` for synchronous, lock-based thread safety —
/// safe to call from any thread including the CGDisplay reconfiguration callback.
final class LogStore: Sendable {
    /// Maximum number of entries retained in the ring buffer.
    let capacity: Int

    enum Level: String, CaseIterable, Comparable {
        case info
        case notice
        case warning
        case error

        /// Numeric severity used for ordering. Adding a new case requires
        /// assigning it a rank — the compiler enforces exhaustive switching.
        var rank: Int {
            switch self {
            case .info: 0
            case .notice: 1
            case .warning: 2
            case .error: 3
            }
        }

        static func < (lhs: Level, rhs: Level) -> Bool {
            lhs.rank < rhs.rank
        }
    }

    struct Entry: Identifiable {
        let id: UInt64
        let timestamp: Date
        let level: Level
        let category: String
        let message: String
    }

    private struct State {
        var buffer: [Entry?]
        var head: Int = 0
        var count: Int = 0
        var nextID: UInt64 = 0
        let capacity: Int

        init(capacity: Int) {
            self.capacity = capacity
            self.buffer = Array(repeating: nil, count: capacity)
        }
    }

    private let state: OSAllocatedUnfairLock<State>

    init(capacity: Int = 500) {
        precondition(capacity > 0, "LogStore capacity must be at least 1")
        self.capacity = capacity
        self.state = OSAllocatedUnfairLock(initialState: State(capacity: capacity))
    }

    func append(level: Level, category: String, message: String) {
        state.withLock { st in
            let entry = Entry(
                id: st.nextID,
                timestamp: Date(),
                level: level,
                category: category,
                message: message
            )
            st.nextID += 1

            let index = (st.head + st.count) % st.capacity
            if st.count < st.capacity {
                st.buffer[index] = entry
                st.count += 1
            } else {
                st.buffer[st.head] = entry
                st.head = (st.head + 1) % st.capacity
            }
        }
    }

    func entries() -> [Entry] {
        state.withLock { st in
            (0 ..< st.count).compactMap { st.buffer[(st.head + $0) % st.capacity] }
        }
    }

    func clear() {
        state.withLock { st in
            st.buffer = Array(repeating: nil, count: st.capacity)
            st.head = 0
            st.count = 0
        }
    }

    /// Formats all entries as a plain-text diagnostic report for clipboard export.
    func formattedReport() -> String {
        let snapshot = entries()
        guard !snapshot.isEmpty else { return "No diagnostic log entries." }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"

        var lines = [
            "Snap Diagnostic Log",
            "Exported: \(formatter.string(from: Date()))",
            "Entries: \(snapshot.count)",
            String(repeating: "─", count: 72)
        ]

        for entry in snapshot {
            let ts = formatter.string(from: entry.timestamp)
            lines.append("\(ts) [\(entry.level.rawValue)] \(entry.category): \(entry.message)")
        }

        return lines.joined(separator: "\n")
    }
}

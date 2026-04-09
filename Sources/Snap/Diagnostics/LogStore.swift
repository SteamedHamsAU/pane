import Foundation
import os

/// Thread-safe in-memory ring buffer for diagnostic log entries.
///
/// Uses `OSAllocatedUnfairLock` for synchronous, lock-based thread safety —
/// safe to call from any thread including the CGDisplay reconfiguration callback.
final class LogStore: Sendable {
    static let shared = LogStore()

    /// Maximum number of entries retained in the ring buffer.
    let capacity: Int

    enum Level: String, CaseIterable, Comparable {
        case info
        case notice
        case warning
        case error

        static func < (lhs: Level, rhs: Level) -> Bool {
            let order: [Level] = [.info, .notice, .warning, .error]
            return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
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
        var entries: [Entry] = []
        var nextID: UInt64 = 0
        let capacity: Int
    }

    private let state: OSAllocatedUnfairLock<State>

    init(capacity: Int = 500) {
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
            st.entries.append(entry)
            if st.entries.count > st.capacity {
                st.entries.removeFirst(st.entries.count - st.capacity)
            }
        }
    }

    func entries() -> [Entry] {
        state.withLock { $0.entries }
    }

    func clear() {
        state.withLock { $0.entries.removeAll() }
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

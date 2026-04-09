import AppKit
import SwiftUI

/// In-app diagnostic log viewer. Shows the ring buffer contents with
/// filtering by category and level, auto-refresh, and clipboard export.
@MainActor
struct DiagnosticsView: View {
    let logStore: LogStore

    @State private var entries: [LogStore.Entry] = []
    @State private var selectedCategory: String?
    @State private var minimumLevel: LogStore.Level = .info
    @State private var refreshTask: Task<Void, Never>?

    private var categories: [String] {
        Array(Set(entries.map(\.category))).sorted()
    }

    private var filteredEntries: [LogStore.Entry] {
        entries.filter { entry in
            if let selected = selectedCategory, entry.category != selected {
                return false
            }
            return entry.level >= minimumLevel
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            filterBar
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            Divider()

            if filteredEntries.isEmpty {
                Spacer()
                Text(entries.isEmpty ? "No log entries yet" : "No entries match filters")
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                logList
            }

            Divider()

            statusBar
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
        }
        .onAppear {
            refresh()
            startAutoRefresh()
        }
        .onDisappear {
            refreshTask?.cancel()
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        HStack(spacing: 8) {
            Picker("Category", selection: $selectedCategory) {
                Text("All Categories").tag(String?.none)
                ForEach(categories, id: \.self) { category in
                    Text(category).tag(String?.some(category))
                }
            }
            .fixedSize()

            Picker("Level", selection: $minimumLevel) {
                ForEach(LogStore.Level.allCases, id: \.self) { level in
                    Text(level.rawValue.capitalized).tag(level)
                }
            }
            .fixedSize()

            Spacer()

            Button {
                let report = logStore.formattedReport()
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(report, forType: .string)
            } label: {
                Label("Copy", systemImage: "doc.on.clipboard")
            }
            .controlSize(.small)
            .help("Copy full log to clipboard")

            Button {
                logStore.clear()
                refresh()
            } label: {
                Label("Clear", systemImage: "trash")
            }
            .controlSize(.small)
            .help("Clear all log entries")
        }
    }

    // MARK: - Log List

    private var logList: some View {
        ScrollViewReader { proxy in
            List(filteredEntries) { entry in
                logEntryRow(entry)
                    .id(entry.id)
            }
            .listStyle(.plain)
            .font(.system(size: 11, design: .monospaced))
            .onChange(of: filteredEntries.last?.id) { _, newID in
                if let newID {
                    withAnimation {
                        proxy.scrollTo(newID, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func logEntryRow(_ entry: LogStore.Entry) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(formatTimestamp(entry.timestamp))
                .foregroundStyle(.secondary)

            Text(levelBadge(entry.level))
                .foregroundStyle(levelColor(entry.level))
                .frame(width: 32, alignment: .leading)

            Text(entry.category)
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)

            Text(entry.message)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        }
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack {
            Text("\(filteredEntries.count) of \(entries.count) entries")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Spacer()
        }
    }

    // MARK: - Helpers

    private func refresh() {
        entries = logStore.entries()
    }

    private func startAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { @MainActor [logStore] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                entries = logStore.entries()
            }
        }
    }

    private static let timestampFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm:ss.SSS"
        return fmt
    }()

    private func formatTimestamp(_ date: Date) -> String {
        Self.timestampFormatter.string(from: date)
    }

    private func levelBadge(_ level: LogStore.Level) -> String {
        switch level {
        case .info: "INFO"
        case .notice: "NOTE"
        case .warning: "WARN"
        case .error: "ERR"
        }
    }

    private func levelColor(_ level: LogStore.Level) -> Color {
        switch level {
        case .info: .secondary
        case .notice: .primary
        case .warning: .orange
        case .error: .red
        }
    }
}

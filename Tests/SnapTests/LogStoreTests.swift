@testable import Snap
import Testing

struct LogStoreTests {
    @Test("Appends entries and returns them in order")
    func appendAndRetrieve() {
        let store = LogStore(capacity: 10)
        store.append(level: .info, category: "Test", message: "first")
        store.append(level: .notice, category: "Test", message: "second")

        let entries = store.entries()
        #expect(entries.count == 2)
        #expect(entries[0].message == "first")
        #expect(entries[1].message == "second")
        #expect(entries[0].id < entries[1].id)
    }

    @Test("Respects capacity and drops oldest entries")
    func capacityEviction() {
        let store = LogStore(capacity: 3)
        store.append(level: .info, category: "A", message: "one")
        store.append(level: .info, category: "A", message: "two")
        store.append(level: .info, category: "A", message: "three")
        store.append(level: .info, category: "A", message: "four")

        let entries = store.entries()
        #expect(entries.count == 3)
        #expect(entries[0].message == "two")
        #expect(entries[1].message == "three")
        #expect(entries[2].message == "four")
    }

    @Test("Clear removes all entries")
    func clearEntries() {
        let store = LogStore(capacity: 10)
        store.append(level: .warning, category: "X", message: "hello")
        #expect(store.entries().count == 1)

        store.clear()
        #expect(store.entries().isEmpty)
    }

    @Test("Entries preserve level and category")
    func entryMetadata() {
        let store = LogStore(capacity: 10)
        store.append(level: .error, category: "Network", message: "timeout")

        let entry = store.entries().first
        #expect(entry?.level == .error)
        #expect(entry?.category == "Network")
        #expect(entry?.message == "timeout")
    }

    @Test("IDs increment monotonically across clears")
    func idMonotonicity() throws {
        let store = LogStore(capacity: 10)
        store.append(level: .info, category: "T", message: "a")
        let idBeforeClear = try #require(store.entries().last).id

        store.clear()
        store.append(level: .info, category: "T", message: "b")
        let idAfterClear = try #require(store.entries().last).id

        #expect(idAfterClear > idBeforeClear)
    }

    @Test("Formatted report includes header and entries")
    func formattedReport() {
        let store = LogStore(capacity: 10)
        store.append(level: .notice, category: "App", message: "started")
        store.append(level: .error, category: "Display", message: "failed")

        let report = store.formattedReport()
        #expect(report.contains("Snap Diagnostic Log"))
        #expect(report.contains("Entries: 2"))
        #expect(report.contains("[notice] App: started"))
        #expect(report.contains("[error] Display: failed"))
    }

    @Test("Formatted report returns placeholder when empty")
    func formattedReportEmpty() {
        let store = LogStore(capacity: 10)
        let report = store.formattedReport()
        #expect(report == "No diagnostic log entries.")
    }

    @Test("Level comparison ordering")
    func levelOrdering() {
        #expect(LogStore.Level.info < .notice)
        #expect(LogStore.Level.notice < .warning)
        #expect(LogStore.Level.warning < .error)
        #expect(!(LogStore.Level.error < .info))
    }
}

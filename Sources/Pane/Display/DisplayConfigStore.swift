import Foundation

/// Persists display configurations keyed by display UUID.
///
/// Storage: `~/Library/Application Support/Pane/displays.plist`
@MainActor
final class DisplayConfigStore {
    private var configurations: [String: DisplayConfiguration] = [:]
    private let fileURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let paneDir = appSupport.appendingPathComponent("Pane", isDirectory: true)
        fileURL = paneDir.appendingPathComponent("displays.plist")

        // Ensure directory exists
        try? FileManager.default.createDirectory(at: paneDir, withIntermediateDirectories: true)

        // Load existing configurations
        load()
    }

    // MARK: - Public API

    func configuration(for uuid: String) -> DisplayConfiguration? {
        configurations[uuid]
    }

    func save(_ config: DisplayConfiguration, for uuid: String) {
        configurations[uuid] = config
        persist()
    }

    func remove(for uuid: String) {
        configurations.removeValue(forKey: uuid)
        persist()
    }

    func allEntries() -> [(uuid: String, config: DisplayConfiguration)] {
        configurations.map { (uuid: $0.key, config: $0.value) }
    }

    func removeAll() {
        configurations.removeAll()
        persist()
    }

    // MARK: - Private

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = PropertyListDecoder()
        configurations = (try? decoder.decode([String: DisplayConfiguration].self, from: data)) ?? [:]
    }

    private func persist() {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        guard let data = try? encoder.encode(configurations) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

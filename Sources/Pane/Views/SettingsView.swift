import SwiftUI
import ServiceManagement

struct SettingsView: View {

    let configStore: DisplayConfigStore
    let checkForUpdates: () -> Void

    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var showNotification = UserDefaults.standard.object(forKey: "showToastOnKnownDisplay") as? Bool ?? true
    @State private var entries: [(uuid: String, config: DisplayConfiguration)] = []

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }
            displaysTab
                .tabItem { Label("Displays", systemImage: "display") }
            aboutTab
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 460, height: 380)
        .onAppear {
            entries = configStore.allEntries()
        }
    }

    // MARK: - General

    private var generalTab: some View {
        Form {
            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    do {
                        if newValue {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        print("Launch at login error: \(error)")
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }

            Toggle("Show notification when known display connects", isOn: $showNotification)
                .onChange(of: showNotification) { _, newValue in
                    UserDefaults.standard.set(newValue, forKey: "showToastOnKnownDisplay")
                }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Remembered Displays

    private var displaysTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            if entries.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    Text("No remembered displays")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                Spacer()
            } else {
                List {
                    ForEach(entries, id: \.uuid) { entry in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.config.displayName ?? String(entry.uuid.prefix(12)) + "…")
                                    .font(.system(size: 13, weight: .medium))
                                Text("\(entry.config.mode.displayName) · \(entry.config.extendPreset.displayName)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button("Forget") {
                                configStore.remove(for: entry.uuid)
                                entries = configStore.allEntries()
                            }
                            .controlSize(.small)
                        }
                    }
                }

                HStack {
                    Spacer()
                    Button("Forget All") {
                        configStore.removeAll()
                        entries = configStore.allEntries()
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }

    // MARK: - About

    private var aboutTab: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "display")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.secondary)

            Text("Pane")
                .font(.system(size: 22, weight: .semibold))

            HStack(spacing: 8) {
                let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
                let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
                Text("v\(version) · build \(build)")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)

                #if DEV_BUILD
                Text("Dev")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(.orange))
                #endif
            }

            Button("Check for Updates…") {
                checkForUpdates()
            }
            .controlSize(.regular)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

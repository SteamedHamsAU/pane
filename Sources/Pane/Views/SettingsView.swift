import AppKit
import ServiceManagement
import SwiftUI

@MainActor
struct SettingsView: View {
    let configStore: DisplayConfigStore
    let checkForUpdates: () -> Void

    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var showNotification = UserDefaults.standard.object(
        forKey: "showToastOnKnownDisplay"
    ) as? Bool ?? true
    @State private var entries: [(uuid: String, config: DisplayConfiguration)] = []
    @State private var settingsWindowBox = WeakWindowBox()
    @State private var settingsWindowID: ObjectIdentifier?

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
        .background(
            WindowReader(
                window: Binding(
                    get: { settingsWindowBox.window },
                    set: { newWindow in
                        settingsWindowBox.window = newWindow
                        settingsWindowID = newWindow.map { ObjectIdentifier($0) }
                    }
                )
            )
        )
        .task(id: settingsWindowID) {
            guard let window = settingsWindowBox.window else { return }

            for await notification in NotificationCenter.default.notifications(
                named: NSWindow.didBecomeKeyNotification,
                object: window
            ) {
                _ = notification // unused payload; we just care that our window became key
                await MainActor.run {
                    entries = configStore.allEntries()
                }
            }
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
                                let displayLabel: String = {
                                    var parts = [entry.config.displayName ?? String(entry.uuid.prefix(12)) + "…"]
                                    if let size = entry.config.screenSizeInches {
                                        parts.append("\(size)″")
                                    }
                                    if let width = entry.config.resolutionWidth {
                                        if let height = entry.config.resolutionHeight {
                                            parts.append("(\(width) × \(height))")
                                        }
                                    }
                                    return parts.joined(separator: " ")
                                }()
                                Text(displayLabel)
                                    .font(.system(size: 13, weight: .medium))
                                HStack(spacing: 4) {
                                    let preset = entry.config.mode == .mirror
                                        ? entry.config.mirrorTarget.displayName
                                        : entry.config.extendPreset.displayName
                                    let rememberSuffix = entry.config.rememberThisDisplay ? "" : " · Prompt"
                                    Text("\(entry.config.mode.displayName) · \(preset)\(rememberSuffix)")
                                }
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

            VStack(spacing: 4) {
                Text("Copyright © 2026 Steamed Hams Pty Ltd")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                Text("Licensed under the MIT License")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Button("Check for Updates…") {
                    checkForUpdates()
                }
                .controlSize(.regular)

                Button("Source Code") {
                    if let url = URL(string: "https://github.com/SteamedHamsAU/pane") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .controlSize(.regular)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

private final class WeakWindowBox {
    weak var window: NSWindow?
}

@MainActor
private final class WindowReaderView: NSView {
    var onWindowChange: ((NSWindow?) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        onWindowChange?(window)
    }
}

@MainActor
private struct WindowReader: NSViewRepresentable {
    @Binding var window: NSWindow?

    func makeNSView(context _: Context) -> WindowReaderView {
        let view = WindowReaderView()
        view.onWindowChange = { [weak view] newWindow in
            guard view != nil else { return }
            Task { @MainActor in
                self.window = newWindow
            }
        }
        return view
    }

    func updateNSView(_: WindowReaderView, context _: Context) {
        // No-op: window changes are handled via viewDidMoveToWindow.
    }
}

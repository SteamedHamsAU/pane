import AppKit
import ServiceManagement
import SwiftUI
import UserNotifications

@MainActor
struct SettingsView: View {
    let configStore: DisplayConfigStore
    let logStore: LogStore
    let checkForUpdates: () -> Void

    @State private var launchAtLogin = false
    @State private var showNotification = UserDefaults.standard.object(
        forKey: "showToastOnKnownDisplay"
    ) as? Bool ?? true
    @State private var diagnosticLogging = UserDefaults.standard.bool(
        forKey: "diagnosticLoggingEnabled"
    )
    @State private var entries: [(uuid: String, config: DisplayConfiguration)] = []
    @State private var settingsWindowBox = WeakWindowBox()
    @State private var settingsWindowID: ObjectIdentifier?
    @State private var selectedTab = 0
    @State private var showDebugDetails = false
    @State private var notificationAuthStatus: UNAuthorizationStatus = .notDetermined

    private var logger: SnapLogger {
        SnapLogger(category: "SettingsView", logStore: logStore)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(0)
            displaysTab
                .tabItem { Label("Displays", systemImage: "display") }
                .tag(1)
            if diagnosticLogging {
                DiagnosticsView(logStore: logStore)
                    .tabItem { Label("Diagnostics", systemImage: "stethoscope") }
                    .tag(2)
            }
            AboutView(checkForUpdates: checkForUpdates)
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag(3)
        }
        .frame(width: 560, height: 520)
        .onAppear {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            entries = configStore.allEntries()
            checkNotificationPermission()
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
                _ = notification
                await MainActor.run {
                    entries = configStore.allEntries()
                    checkNotificationPermission()
                }
            }
        }
        .onChange(of: selectedTab) { _, newValue in
            if newValue == 1, NSEvent.modifierFlags.contains(.option) {
                showDebugDetails.toggle()
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
                        logger.error("Launch at login error: \(error)")
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }

            Section {
                Toggle("Show notification when known display connects", isOn: $showNotification)
                    .onChange(of: showNotification) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "showToastOnKnownDisplay")
                        if newValue {
                            requestNotificationPermissionIfNeeded()
                        }
                    }

                if showNotification {
                    notificationPermissionStatus
                }
            }

            Section {
                Toggle("Enable diagnostic logging", isOn: $diagnosticLogging)
                    .onChange(of: diagnosticLogging) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "diagnosticLoggingEnabled")
                        logStore.isEnabled = newValue
                        if !newValue, selectedTab == 2 {
                            selectedTab = 0
                        }
                    }

                if !diagnosticLogging {
                    Text("When enabled, a Diagnostics tab appears with an in-app log viewer.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Notification Permission

    @ViewBuilder
    private var notificationPermissionStatus: some View {
        switch notificationAuthStatus {
        case .authorized, .provisional, .ephemeral:
            Label("Notifications allowed", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.system(size: 12))
        case .denied:
            HStack {
                Label("Notification permission denied", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.system(size: 12))
                Spacer()
                Button("Open Notification Settings") {
                    openNotificationSettings()
                }
                .controlSize(.small)
            }
        case .notDetermined:
            HStack {
                Label("Permission not yet requested", systemImage: "questionmark.circle")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 12))
                Spacer()
                Button("Request Permission") {
                    requestNotificationPermission()
                }
                .controlSize(.small)
            }
        @unknown default:
            EmptyView()
        }
    }

    private func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                notificationAuthStatus = settings.authorizationStatus
            }
        }
    }

    private func requestNotificationPermissionIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                notificationAuthStatus = settings.authorizationStatus
                if settings.authorizationStatus == .notDetermined {
                    requestNotificationPermission()
                }
            }
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in
            // Re-read actual settings rather than assuming granted/denied,
            // in case the request failed for a transient reason.
            Task { @MainActor in
                self.checkNotificationPermission()
            }
        }
    }

    private func openNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
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

                                if showDebugDetails {
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(entry.uuid)
                                        if let date = entry.config.lastConnected {
                                            let stamp = date.formatted(
                                                date: .abbreviated,
                                                time: .shortened
                                            )
                                            Text("Last connected: \(stamp)")
                                        } else {
                                            Text("Last connected: unknown")
                                        }
                                    }
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 2)
                                }
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

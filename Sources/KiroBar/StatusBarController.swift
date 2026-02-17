import AppKit
import SwiftUI
import KiroBarCore

class KiroBarState: ObservableObject {
    @Published var usage: KiroUsage?
    @Published var error: String?
    @Published var isRefreshing = false
}

struct KiroMenuView: View {
    @ObservedObject var state: KiroBarState
    let onRefresh: () -> Void
    let onSettings: () -> Void
    let onQuit: () -> Void
    
    private let kiroOrange = Color(red: 1.0, green: 0.6, blue: 0)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Kiro")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                    if let u = state.usage {
                        Text(u.planName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                if let e = state.error {
                    Text(e)
                        .font(.footnote)
                        .foregroundStyle(.red)
                } else if state.usage == nil {
                    Text(state.isRefreshing ? "Refreshing..." : "Loading...")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            
            if let u = state.usage {
                Divider().padding(.horizontal, 12)
                
                // Credits section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Credits")
                        .font(.body)
                        .fontWeight(.medium)
                    
                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.gray.opacity(0.3))
                            Capsule()
                                .fill(kiroOrange)
                                .frame(width: geo.size.width * Double(u.percent) / 100)
                        }
                    }
                    .frame(height: 6)
                    
                    HStack {
                        Text("\(u.percent)% used")
                            .font(.footnote)
                        Spacer()
                        if let r = u.resetsAt {
                            Text("Resets \(r, format: .dateTime.month().day())")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Text(String(format: "%.1f of %.0f covered in plan", u.creditsUsed, u.creditsTotal))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            
            Divider().padding(.horizontal, 12)
            
            // Actions
            VStack(spacing: 0) {
                Button(action: onRefresh) {
                    HStack {
                        Text("Refresh")
                        Spacer()
                        if state.isRefreshing {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("⌘R").foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(MenuButtonStyle())
                .disabled(state.isRefreshing)
                
                Button(action: onSettings) {
                    HStack {
                        Text("Settings...")
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(MenuButtonStyle())
                
                Button(action: onQuit) {
                    HStack {
                        Text("Quit")
                        Spacer()
                        Text("⌘Q").foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(MenuButtonStyle())
            }
        }
        .frame(width: 280)
        .background(VisualEffectView())
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct MenuButtonStyle: ButtonStyle {
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(configuration.isPressed ? Color.accentColor.opacity(0.3) : (isHovered ? Color.accentColor.opacity(0.15) : Color.clear))
            .onHover { isHovered = $0 }
    }
}

struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .popover
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

struct SettingsView: View {
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    
    var body: some View {
        Form {
            Toggle("Launch at login", isOn: Binding(
                get: { launchAtLogin },
                set: { launchAtLogin = $0; LaunchAtLogin.isEnabled = $0 }
            ))
            Link("About KiroBar", destination: URL(string: "https://github.com/nihal111/KiroBar")!)
        }
        .padding(20)
        .frame(width: 250)
    }
}

class LaunchAtLogin {
    private static let plistPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/LaunchAgents/com.kirobar.app.plist")
    
    static var isEnabled: Bool {
        get { FileManager.default.fileExists(atPath: plistPath.path) }
        set { newValue ? install() : uninstall() }
    }
    
    private static func install() {
        let execPath = Bundle.main.executablePath ?? ProcessInfo.processInfo.arguments[0]
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key><string>com.kirobar.app</string>
            <key>ProgramArguments</key><array><string>\(execPath)</string></array>
            <key>RunAtLoad</key><true/>
        </dict>
        </plist>
        """
        try? plist.write(to: plistPath, atomically: true, encoding: .utf8)
    }
    
    private static func uninstall() {
        try? FileManager.default.removeItem(at: plistPath)
    }
}

class StatusBarController: NSObject {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var settingsWindow: NSWindow?
    private let state = KiroBarState()
    private let probe = KiroUsageProbe()
    private var eventMonitor: Any?
    
    override init() {
        super.init()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        // Set up icon + percentage display
        if let button = statusItem.button {
            button.image = loadMenuBarIcon()
            button.image?.isTemplate = true
            button.imagePosition = .imageLeft
            button.title = " --"
            button.action = #selector(togglePopover)
            button.target = self
        }
        
        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        setupPopover()
        
        refresh()
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in self?.refresh() }
        
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.popover.performClose(nil)
        }
    }
    
    private func loadMenuBarIcon() -> NSImage? {
        guard let url = Bundle.module.url(forResource: "kiro-icon", withExtension: "png"),
              let image = NSImage(contentsOf: url) else { return nil }
        image.size = NSSize(width: 18, height: 18)
        return image
    }
    
    deinit {
        if let monitor = eventMonitor { NSEvent.removeMonitor(monitor) }
    }
    
    func refresh() {
        state.isRefreshing = true
        Task {
            do {
                let u = try await probe.fetch()
                await MainActor.run {
                    self.state.usage = u
                    self.state.error = nil
                    self.state.isRefreshing = false
                    self.statusItem.button?.title = " \(u.percent)%"
                }
            } catch {
                await MainActor.run {
                    self.state.error = error.localizedDescription
                    self.state.isRefreshing = false
                    self.statusItem.button?.title = " ⚠️"
                }
            }
        }
    }
    
    private func setupPopover() {
        popover.contentViewController = NSHostingController(rootView: 
            KiroMenuView(
                state: state,
                onRefresh: { [weak self] in self?.refresh() },
                onSettings: { [weak self] in self?.showSettings() },
                onQuit: { NSApp.terminate(nil) }
            )
        )
    }
    
    private func showSettings() {
        popover.performClose(nil)
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: .zero,
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "KiroBar Settings"
            window.center()
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }
        settingsWindow?.contentView = NSHostingView(rootView: SettingsView())
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}


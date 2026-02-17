import AppKit
import SwiftUI

struct KiroMenuView: View {
    let usage: KiroUsage?
    let error: String?
    let onRefresh: () -> Void
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
                    if let u = usage {
                        Text(u.planName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                if let e = error {
                    Text(e)
                        .font(.footnote)
                        .foregroundStyle(.red)
                } else if usage == nil {
                    Text("Loading...")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            
            if let u = usage {
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
                        Text("⌘R").foregroundStyle(.secondary)
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
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(configuration.isPressed ? Color.accentColor.opacity(0.2) : Color.clear)
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

class StatusBarController: NSObject {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var usage: KiroUsage?
    private var error: String?
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
        updatePopover()
        
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
        Task {
            do {
                let u = try await probe.fetch()
                await MainActor.run {
                    self.usage = u
                    self.error = nil
                    self.statusItem.button?.title = " \(u.percent)%"
                    self.updatePopover()
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.statusItem.button?.title = " ⚠️"
                    self.updatePopover()
                }
            }
        }
    }
    
    private func updatePopover() {
        popover.contentViewController = NSHostingController(rootView: 
            KiroMenuView(
                usage: usage,
                error: error,
                onRefresh: { [weak self] in self?.refresh() },
                onQuit: { NSApp.terminate(nil) }
            )
        )
    }
    
    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}


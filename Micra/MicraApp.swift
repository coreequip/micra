import SwiftUI
import AppKit

@main
struct MicraApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var state = MicraState()
    var statusItem: NSStatusItem?
    var popover = NSPopover()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let contentView = PopoverView(state: state)
        popover.contentSize = NSSize(width: 280, height: 340)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: contentView)
        
        statusItem = NSStatusBar.system.statusItem(withLength: 18)
        
        if let button = statusItem?.button {
            button.action = #selector(handleStatusItemClick(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            updateIcon()
        }
        
        setupIconObserver()
    }
    
    func setupIconObserver() {
        withObservationTracking {
            updateIcon()
        } onChange: {
            Task { @MainActor in
                self.setupIconObserver()
            }
        }
    }

    @objc func handleStatusItemClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        
        if event?.type == .rightMouseUp {
            if popover.isShown {
                popover.performClose(sender)
            } else {
                popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
                popover.contentViewController?.view.window?.makeKey()
            }
        } else {
            state.toggleMute()
        }
    }

    func updateIcon() {
        guard let button = statusItem?.button else { return }

        let imageName = state.isMuted ? "mic.slash.fill" : "mic.fill"
        
        let canvasSize = NSSize(width: 18, height: 18)
        let iconImage = NSImage(size: canvasSize, flipped: false) { rect in
            let config = NSImage.SymbolConfiguration(pointSize: 14.5, weight: .medium)
            if let symbol = NSImage(systemSymbolName: imageName, accessibilityDescription: nil)?
                .withSymbolConfiguration(config) {
                
                let symbolSize = symbol.size
                let destRect = NSRect(
                    x: (rect.width - symbolSize.width) / 2,
                    y: (rect.height - symbolSize.height) / 2,
                    width: symbolSize.width,
                    height: symbolSize.height
                )
                symbol.draw(in: destRect)
                return true
            }
            return false
        }

        iconImage.isTemplate = true
        button.image = iconImage
        button.imagePosition = .imageOnly

        button.alphaValue = (state.isMuted && !state.isRunning) ? 0.4 : 1.0

        if state.isRunning {
            button.contentFilters = [CIFilter(name: "CIFalseColor", parameters: [
                "inputColor0": CIColor(red: 1, green: 0, blue: 0),
                "inputColor1": CIColor(red: 1, green: 0, blue: 0)
            ])!]
            button.alphaValue = 1.0
        } else {
            button.contentFilters = []
        }
    }
}

struct PopoverView: View {
    @Bindable var state: MicraState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Device Name
            Text(state.deviceName)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.primary.opacity(0.9))
                .lineLimit(1)
                .padding(.top, 24)
                .padding(.horizontal, 20)
            
            Divider()
                .padding(.top, 12)
                .padding(.horizontal, 20)
                .opacity(0.5)
            
            // Shortcut Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Mic mute shortcut:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                
                ShortcutRecorder(shortcut: $state.currentShortcut)
            }
            .padding(.top, 16)
            .padding(.horizontal, 20)
            
            // Toggles
            VStack(alignment: .leading, spacing: 14) {
                Toggle("Push-to-talk mode", isOn: $state.isWalkieTalkieMode)
                Toggle("Lock input device", isOn: $state.isLockedToCurrentDevice)
                Toggle("Play feedback sound", isOn: $state.isAudioFeedbackEnabled)
                Toggle("Launch at login", isOn: $state.launchAtLogin)
            }
            .toggleStyle(.checkbox)
            .font(.system(size: 14, weight: .medium))
            .padding(.top, 20)
            .padding(.horizontal, 20)
            
            Spacer(minLength: 24)
            
            Divider()
                .padding(.horizontal, 20)
                .opacity(0.5)
            
            // Footer Buttons
            HStack {
                Button("About") {
                    if let url = URL(string: "https://micr.app") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Quit Micra") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, 16)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .frame(width: 280)
        .background(VisualEffectView().ignoresSafeArea())
    }
}

struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = .popover
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

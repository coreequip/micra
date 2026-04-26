import SwiftUI
import AppKit

struct ShortcutRecorder: View {
    @Binding var shortcut: Shortcut?
    @State private var isRecording = false
    @State private var eventMonitor: Any?
    @State private var flagsMonitor: Any?
    @State private var liveDisplay: String = ""

    var body: some View {
        Button(action: {
            isRecording.toggle()
            if isRecording { 
                liveDisplay = ""
                startRecording() 
            } else { 
                stopRecording() 
            }
        }) {
            HStack(alignment: .center) {
                if isRecording {
                    Text(liveDisplay.isEmpty ? "Recording..." : liveDisplay)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.accentColor)
                } else if let shortcut = shortcut {
                    Text(shortcut.displayString)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                } else {
                    Text("Click to record")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                
                Spacer()
                
                if shortcut != nil && !isRecording {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary.opacity(0.5))
                        .onTapGesture { self.shortcut = nil }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.05)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(isRecording ? Color.accentColor : Color.secondary.opacity(0.1), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .focusable(false)
        .onDisappear { stopRecording() }
    }

    private func startRecording() {
        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            let modifiers = mapToCarbonModifiers(event.modifierFlags)
            liveDisplay = modifiersToString(modifiers)
            return event
        }

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 {
                stopRecording()
                return nil
            }
            
            let carbonModifiers = mapToCarbonModifiers(event.modifierFlags)
            if carbonModifiers != 0 {
                self.shortcut = Shortcut(keyCode: event.keyCode, modifierFlags: carbonModifiers)
                stopRecording()
                return nil 
            }
            
            return event
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor = eventMonitor { NSEvent.removeMonitor(monitor); eventMonitor = nil }
        if let monitor = flagsMonitor { NSEvent.removeMonitor(monitor); flagsMonitor = nil }
    }

    private func modifiersToString(_ flags: UInt32) -> String {
        let allModifiersMask: UInt32 = 0x1000 | 0x0800 | 0x0200 | 0x0100
        if (flags & allModifiersMask) == allModifiersMask {
            return "✦"
        }
        
        var components: [String] = []
        if flags & UInt32(0x1000) != 0 { components.append("⌃") }
        if flags & UInt32(0x0800) != 0 { components.append("⌥") }
        if flags & UInt32(0x0200) != 0 { components.append("⇧") }
        if flags & UInt32(0x0100) != 0 { components.append("⌘") }
        return components.joined(separator: " ")
    }

    private func mapToCarbonModifiers(_ flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(0x0100) }
        if flags.contains(.shift) { carbon |= UInt32(0x0200) }
        if flags.contains(.option) { carbon |= UInt32(0x0800) }
        if flags.contains(.control) { carbon |= UInt32(0x1000) }
        return carbon
    }
}

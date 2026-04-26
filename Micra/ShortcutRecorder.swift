import SwiftUI
import AppKit

struct ShortcutRecorder: View {
    @Binding var shortcut: Shortcut?
    @State private var isRecording = false
    
    var body: some View {
        Button(action: { isRecording.toggle() }) {
            Text(isRecording ? "Press keys..." : (shortcut != nil ? "Recorded" : "Click to record"))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .background(isRecording ? Color.blue.opacity(0.2) : Color.clear)
    }
}

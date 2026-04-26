import Foundation
import AppKit
import Carbon

struct Shortcut: Codable, Equatable {
    let keyCode: UInt16
    let modifierFlags: UInt32 // Carbon Modifiers
    
    init(keyCode: UInt16, modifierFlags: UInt32) {
        self.keyCode = keyCode
        self.modifierFlags = modifierFlags
    }
    
    // Initializer for compatibility with Int-based keycodes
    init(keyCode: Int, modifierFlags: UInt32) {
        self.keyCode = UInt16(keyCode)
        self.modifierFlags = modifierFlags
    }
    
    var displayString: String {
        let allModifiersMask: UInt32 = 0x1000 | 0x0800 | 0x0200 | 0x0100
        var components: [String] = []
        
        if (modifierFlags & allModifiersMask) == allModifiersMask {
            components.append("✦")
        } else {
            // Standard macOS modifier order: Ctrl, Opt, Shift, Cmd
            if modifierFlags & UInt32(0x1000) != 0 { components.append("⌃") }
            if modifierFlags & UInt32(0x0800) != 0 { components.append("⌥") }
            if modifierFlags & UInt32(0x0200) != 0 { components.append("⇧") }
            if modifierFlags & UInt32(0x0100) != 0 { components.append("⌘") }
        }
        
        components.append(keyCodeToString(keyCode))
        return components.joined(separator: " ")
    }
    
    private func keyCodeToString(_ keyCode: UInt16) -> String {
        // 1. Hardcoded mapping for special/fallback keys
        let specialKeys: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N", 46: "M", 47: ".", 50: "`",
            49: "Space", 36: "↩", 48: "⇥", 51: "⌫", 53: "⎋", 
            123: "←", 124: "→", 125: "↓", 126: "↑",
            96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12"
        ]
        
        // 2. Try dynamic translation first for international layouts
        if let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
           let layoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) {
            
            let layoutDataPtr = UnsafeRawPointer(layoutData).assumingMemoryBound(to: UCKeyboardLayout.self)
            var deadKeyState: UInt32 = 0
            var actualStringLength = 0
            var unicodeString = [UniChar](repeating: 0, count: 4)
            
            let status = UCKeyTranslate(layoutDataPtr,
                                        keyCode,
                                        UInt16(kUCKeyActionDisplay),
                                        0,
                                        UInt32(LMGetKbdType()),
                                        UInt32(kUCKeyTranslateNoDeadKeysBit),
                                        &deadKeyState,
                                        4,
                                        &actualStringLength,
                                        &unicodeString)
            
            if status == noErr && actualStringLength > 0 {
                let result = String(utf16CodeUnits: unicodeString, count: actualStringLength).uppercased()
                if !result.isEmpty { return result }
            }
        }

        // 3. Fallback to hardcoded mapping if dynamic fails
        return specialKeys[keyCode] ?? "Key(\(keyCode))"
    }
}

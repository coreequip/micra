import Foundation
import AppKit

struct Shortcut: Codable, Equatable {
    var keyCode: Int
    var modifierFlags: UInt32
}

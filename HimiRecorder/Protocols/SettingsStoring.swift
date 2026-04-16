import Foundation

/// Represents a keyboard shortcut combination.
struct KeyCombo: Codable, Equatable {
    /// The key code (Carbon virtual key code).
    let keyCode: UInt16
    
    /// Modifier flags (command, option, control, shift).
    let modifiers: UInt
    
    /// Human-readable description of the shortcut (e.g., "⌘⇧R").
    var displayString: String {
        var parts: [String] = []
        if modifiers & NSEvent.ModifierFlags.control.rawValue != 0 { parts.append("⌃") }
        if modifiers & NSEvent.ModifierFlags.option.rawValue != 0 { parts.append("⌥") }
        if modifiers & NSEvent.ModifierFlags.shift.rawValue != 0 { parts.append("⇧") }
        if modifiers & NSEvent.ModifierFlags.command.rawValue != 0 { parts.append("⌘") }
        parts.append(KeyCombo.keyCodeToString(keyCode))
        return parts.joined()
    }
    
    static func keyCodeToString(_ keyCode: UInt16) -> String {
        let mapping: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L",
            38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
            45: "N", 46: "M", 47: ".", 49: "Space", 50: "`",
            36: "↩", 48: "⇥", 51: "⌫", 53: "⎋",
            96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8",
            101: "F9", 109: "F10", 103: "F11", 111: "F12",
            118: "F4", 120: "F2", 122: "F1",
            123: "←", 124: "→", 125: "↓", 126: "↑"
        ]
        return mapping[keyCode] ?? "Key\(keyCode)"
    }
}

import Cocoa

/// Protocol abstracting settings storage for testability.
/// Production uses UserDefaults; tests inject MockSettingsStore.
protocol SettingsStoring: AnyObject {
    /// Video frame rate (24, 30, or 60). Default: 60.
    var frameRate: Int { get set }
    
    /// Default export directory path.
    var defaultExportPath: String? { get set }
    
    /// Shortcut to start recording.
    var startRecordingShortcut: KeyCombo? { get set }
    
    /// Shortcut to stop recording.
    var stopRecordingShortcut: KeyCombo? { get set }
}

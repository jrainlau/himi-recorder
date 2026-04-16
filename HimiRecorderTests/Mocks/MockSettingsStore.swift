import Foundation
@testable import HimiRecorder

/// Mock implementation of SettingsStoring using in-memory dictionary.
final class MockSettingsStore: SettingsStoring {
    var frameRate: Int = 60
    var defaultExportPath: String?
    var startRecordingShortcut: KeyCombo?
    var stopRecordingShortcut: KeyCombo?
}

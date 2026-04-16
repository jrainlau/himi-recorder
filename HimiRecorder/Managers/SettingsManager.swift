import Foundation

/// Manages user settings persistence via UserDefaults.
/// Conforms to SettingsStoring protocol for testability.
final class SettingsManager: SettingsStoring {
    
    private let defaults: UserDefaults
    
    private enum Keys {
        static let frameRate = "com.himi.recorder.frameRate"
        static let defaultExportPath = "com.himi.recorder.defaultExportPath"
        static let startRecordingShortcut = "com.himi.recorder.startRecordingShortcut"
        static let stopRecordingShortcut = "com.himi.recorder.stopRecordingShortcut"
    }
    
    static let validFrameRates = [24, 30, 60]
    static let defaultFrameRate = 60
    
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        registerDefaults()
    }
    
    private func registerDefaults() {
        defaults.register(defaults: [
            Keys.frameRate: SettingsManager.defaultFrameRate
        ])
    }
    
    // MARK: - SettingsStoring
    
    var frameRate: Int {
        get {
            let value = defaults.integer(forKey: Keys.frameRate)
            return SettingsManager.validFrameRates.contains(value) ? value : SettingsManager.defaultFrameRate
        }
        set {
            let validValue = SettingsManager.validFrameRates.contains(newValue) ? newValue : SettingsManager.defaultFrameRate
            defaults.set(validValue, forKey: Keys.frameRate)
        }
    }
    
    var defaultExportPath: String? {
        get { defaults.string(forKey: Keys.defaultExportPath) }
        set { defaults.set(newValue, forKey: Keys.defaultExportPath) }
    }
    
    var startRecordingShortcut: KeyCombo? {
        get { loadKeyCombo(forKey: Keys.startRecordingShortcut) }
        set { saveKeyCombo(newValue, forKey: Keys.startRecordingShortcut) }
    }
    
    var stopRecordingShortcut: KeyCombo? {
        get { loadKeyCombo(forKey: Keys.stopRecordingShortcut) }
        set { saveKeyCombo(newValue, forKey: Keys.stopRecordingShortcut) }
    }
    
    // MARK: - Private Helpers
    
    private func loadKeyCombo(forKey key: String) -> KeyCombo? {
        guard let data = defaults.data(forKey: key) else { return nil }
        do {
            return try JSONDecoder().decode(KeyCombo.self, from: data)
        } catch {
            console_log("Failed to decode KeyCombo for key \(key): \(error)")
            return nil
        }
    }
    
    private func saveKeyCombo(_ combo: KeyCombo?, forKey key: String) {
        guard let combo = combo else {
            defaults.removeObject(forKey: key)
            return
        }
        do {
            let data = try JSONEncoder().encode(combo)
            defaults.set(data, forKey: key)
        } catch {
            console_log("Failed to encode KeyCombo for key \(key): \(error)")
        }
    }
}

private func console_log(_ message: String) {
    #if DEBUG
    print("[SettingsManager] \(message)")
    #endif
}

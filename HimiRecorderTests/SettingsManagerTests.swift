import XCTest
@testable import HimiRecorder

final class SettingsManagerTests: XCTestCase {
    
    private var sut: SettingsManager!
    private var testDefaults: UserDefaults!
    
    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: "com.himi.recorder.tests.\(UUID().uuidString)")!
        sut = SettingsManager(defaults: testDefaults)
    }
    
    override func tearDown() {
        testDefaults.removePersistentDomain(forName: testDefaults.volatileDomainNames.first ?? "")
        sut = nil
        testDefaults = nil
        super.tearDown()
    }
    
    // MARK: - Frame Rate Tests
    
    func testDefaultFrameRateIs60() {
        XCTAssertEqual(sut.frameRate, 60)
    }
    
    func testSetFrameRate24() {
        sut.frameRate = 24
        XCTAssertEqual(sut.frameRate, 24)
    }
    
    func testSetFrameRate30() {
        sut.frameRate = 30
        XCTAssertEqual(sut.frameRate, 30)
    }
    
    func testSetFrameRate60() {
        sut.frameRate = 60
        XCTAssertEqual(sut.frameRate, 60)
    }
    
    func testInvalidFrameRateFallsBackToDefault() {
        sut.frameRate = 45
        XCTAssertEqual(sut.frameRate, 60, "Invalid frame rate should fall back to default 60")
    }
    
    func testZeroFrameRateFallsBackToDefault() {
        sut.frameRate = 0
        XCTAssertEqual(sut.frameRate, 60)
    }
    
    func testNegativeFrameRateFallsBackToDefault() {
        sut.frameRate = -1
        XCTAssertEqual(sut.frameRate, 60)
    }
    
    // MARK: - Export Path Tests
    
    func testDefaultExportPathIsNil() {
        XCTAssertNil(sut.defaultExportPath)
    }
    
    func testSetExportPath() {
        let path = "/Users/test/Desktop"
        sut.defaultExportPath = path
        XCTAssertEqual(sut.defaultExportPath, path)
    }
    
    func testClearExportPath() {
        sut.defaultExportPath = "/some/path"
        sut.defaultExportPath = nil
        XCTAssertNil(sut.defaultExportPath)
    }
    
    // MARK: - Shortcut Tests
    
    func testDefaultStartShortcutIsNil() {
        XCTAssertNil(sut.startRecordingShortcut)
    }
    
    func testDefaultStopShortcutIsNil() {
        XCTAssertNil(sut.stopRecordingShortcut)
    }
    
    func testSetStartRecordingShortcut() {
        let combo = KeyCombo(keyCode: 15, modifiers: NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue)
        sut.startRecordingShortcut = combo
        XCTAssertEqual(sut.startRecordingShortcut, combo)
    }
    
    func testSetStopRecordingShortcut() {
        let combo = KeyCombo(keyCode: 1, modifiers: NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue)
        sut.stopRecordingShortcut = combo
        XCTAssertEqual(sut.stopRecordingShortcut, combo)
    }
    
    func testClearStartShortcut() {
        let combo = KeyCombo(keyCode: 15, modifiers: NSEvent.ModifierFlags.command.rawValue)
        sut.startRecordingShortcut = combo
        sut.startRecordingShortcut = nil
        XCTAssertNil(sut.startRecordingShortcut)
    }
    
    func testShortcutPersistenceAcrossInstances() {
        let combo = KeyCombo(keyCode: 15, modifiers: NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue)
        sut.startRecordingShortcut = combo
        
        let newManager = SettingsManager(defaults: testDefaults)
        XCTAssertEqual(newManager.startRecordingShortcut, combo)
    }
    
    func testFrameRatePersistenceAcrossInstances() {
        sut.frameRate = 30
        
        let newManager = SettingsManager(defaults: testDefaults)
        XCTAssertEqual(newManager.frameRate, 30)
    }
    
    // MARK: - KeyCombo Display String Tests
    
    func testKeyComboDisplayString() {
        let combo = KeyCombo(
            keyCode: 15, // R
            modifiers: NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue
        )
        XCTAssertTrue(combo.displayString.contains("⌘"), "Should contain command symbol")
        XCTAssertTrue(combo.displayString.contains("⇧"), "Should contain shift symbol")
        XCTAssertTrue(combo.displayString.contains("R"), "Should contain key name")
    }
    
    func testKeyComboEquality() {
        let combo1 = KeyCombo(keyCode: 15, modifiers: NSEvent.ModifierFlags.command.rawValue)
        let combo2 = KeyCombo(keyCode: 15, modifiers: NSEvent.ModifierFlags.command.rawValue)
        let combo3 = KeyCombo(keyCode: 1, modifiers: NSEvent.ModifierFlags.command.rawValue)
        
        XCTAssertEqual(combo1, combo2)
        XCTAssertNotEqual(combo1, combo3)
    }
    
    // MARK: - MockSettingsStore Tests
    
    func testMockSettingsStoreConformsToProtocol() {
        let mock = MockSettingsStore()
        let settings: SettingsStoring = mock
        
        settings.frameRate = 30
        XCTAssertEqual(settings.frameRate, 30)
        
        settings.defaultExportPath = "/test"
        XCTAssertEqual(settings.defaultExportPath, "/test")
        
        let combo = KeyCombo(keyCode: 15, modifiers: 0)
        settings.startRecordingShortcut = combo
        XCTAssertEqual(settings.startRecordingShortcut, combo)
    }
}

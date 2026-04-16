import XCTest
@testable import HimiRecorder

final class HotKeyManagerTests: XCTestCase {
    
    // MARK: - MockHotKeyRegistrar Tests
    
    func testMockRegister() {
        let mock = MockHotKeyRegistrar()
        let combo = KeyCombo(keyCode: 15, modifiers: NSEvent.ModifierFlags.command.rawValue)
        
        let token = mock.register(shortcut: combo, action: {})
        XCTAssertNotNil(token)
        XCTAssertEqual(mock.registerCallCount, 1)
        XCTAssertEqual(mock.registeredShortcuts.count, 1)
        XCTAssertEqual(mock.registeredShortcuts.first, combo)
    }
    
    func testMockUnregister() {
        let mock = MockHotKeyRegistrar()
        let combo = KeyCombo(keyCode: 15, modifiers: NSEvent.ModifierFlags.command.rawValue)
        
        let token = mock.register(shortcut: combo, action: {})!
        mock.unregister(token)
        
        XCTAssertEqual(mock.unregisterCallCount, 1)
    }
    
    func testMockUnregisterAll() {
        let mock = MockHotKeyRegistrar()
        let combo1 = KeyCombo(keyCode: 15, modifiers: NSEvent.ModifierFlags.command.rawValue)
        let combo2 = KeyCombo(keyCode: 1, modifiers: NSEvent.ModifierFlags.command.rawValue)
        
        _ = mock.register(shortcut: combo1, action: {})
        _ = mock.register(shortcut: combo2, action: {})
        
        mock.unregisterAll()
        
        XCTAssertEqual(mock.unregisterAllCallCount, 1)
        XCTAssertEqual(mock.registeredShortcuts.count, 0)
    }
    
    func testMockSimulateTrigger() {
        let mock = MockHotKeyRegistrar()
        let combo = KeyCombo(keyCode: 15, modifiers: NSEvent.ModifierFlags.command.rawValue)
        
        var triggered = false
        _ = mock.register(shortcut: combo, action: { triggered = true })
        
        mock.simulateTrigger(index: 0)
        XCTAssertTrue(triggered)
    }
    
    func testMockMultipleRegistrations() {
        let mock = MockHotKeyRegistrar()
        let combo1 = KeyCombo(keyCode: 15, modifiers: NSEvent.ModifierFlags.command.rawValue)
        let combo2 = KeyCombo(keyCode: 1, modifiers: NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue)
        
        var trigger1 = false
        var trigger2 = false
        
        _ = mock.register(shortcut: combo1, action: { trigger1 = true })
        _ = mock.register(shortcut: combo2, action: { trigger2 = true })
        
        mock.simulateTrigger(index: 0)
        XCTAssertTrue(trigger1)
        XCTAssertFalse(trigger2)
        
        mock.simulateTrigger(index: 1)
        XCTAssertTrue(trigger2)
    }
    
    // MARK: - Real HotKeyManager Tests
    
    func testRealHotKeyManagerRegister() {
        let manager = HotKeyManager()
        let combo = KeyCombo(keyCode: 15, modifiers: NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue)
        
        let token = manager.register(shortcut: combo, action: {})
        XCTAssertNotNil(token)
        
        manager.unregisterAll()
    }
    
    func testRealHotKeyManagerUnregister() {
        let manager = HotKeyManager()
        let combo = KeyCombo(keyCode: 15, modifiers: NSEvent.ModifierFlags.command.rawValue)
        
        let token = manager.register(shortcut: combo, action: {})!
        // Should not crash
        manager.unregister(token)
    }
    
    func testRealHotKeyManagerUnregisterAll() {
        let manager = HotKeyManager()
        let combo1 = KeyCombo(keyCode: 15, modifiers: NSEvent.ModifierFlags.command.rawValue)
        let combo2 = KeyCombo(keyCode: 1, modifiers: NSEvent.ModifierFlags.command.rawValue)
        
        _ = manager.register(shortcut: combo1, action: {})
        _ = manager.register(shortcut: combo2, action: {})
        
        // Should not crash
        manager.unregisterAll()
    }
    
    func testProtocolConformance() {
        let real: HotKeyRegistering = HotKeyManager()
        let mock: HotKeyRegistering = MockHotKeyRegistrar()
        
        XCTAssertNotNil(real)
        XCTAssertNotNil(mock)
    }
}

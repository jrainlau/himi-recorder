import Foundation
@testable import HimiRecorder

/// Mock hotkey registrar for testing.
final class MockHotKeyRegistrar: HotKeyRegistering {
    var registerCallCount = 0
    var unregisterCallCount = 0
    var unregisterAllCallCount = 0
    var registeredShortcuts: [KeyCombo] = []
    var registeredActions: [() -> Void] = []
    private var nextToken = 0
    
    func register(shortcut: KeyCombo, action: @escaping () -> Void) -> Any? {
        registerCallCount += 1
        registeredShortcuts.append(shortcut)
        registeredActions.append(action)
        nextToken += 1
        return nextToken
    }
    
    func unregister(_ token: Any) {
        unregisterCallCount += 1
    }
    
    func unregisterAll() {
        unregisterAllCallCount += 1
        registeredShortcuts.removeAll()
        registeredActions.removeAll()
    }
    
    /// Simulate triggering the last registered shortcut.
    func simulateTrigger(index: Int = 0) {
        guard index < registeredActions.count else { return }
        registeredActions[index]()
    }
}

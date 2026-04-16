import Foundation

/// Protocol abstracting global hotkey registration for testability.
/// Production uses NSEvent.addGlobalMonitorForEvents; tests inject MockHotKeyRegistrar.
protocol HotKeyRegistering: AnyObject {
    /// Register a global hotkey.
    /// - Parameters:
    ///   - shortcut: The key combination to listen for.
    ///   - action: Callback when the hotkey is pressed.
    /// - Returns: A registration token to use for unregistering, or nil on failure.
    func register(shortcut: KeyCombo, action: @escaping () -> Void) -> Any?
    
    /// Unregister a previously registered hotkey.
    /// - Parameter token: The registration token returned from register().
    func unregister(_ token: Any)
    
    /// Unregister all hotkeys.
    func unregisterAll()
}

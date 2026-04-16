import Cocoa

/// Manages global hotkeys using NSEvent monitors.
final class HotKeyManager: HotKeyRegistering {
    
    private struct Registration {
        let shortcut: KeyCombo
        let action: () -> Void
        let globalMonitor: Any?
        let localMonitor: Any?
    }
    
    private var registrations: [Int: Registration] = [:]
    private var nextToken = 0
    
    func register(shortcut: KeyCombo, action: @escaping () -> Void) -> Any? {
        let token = nextToken
        nextToken += 1
        
        let globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event, token: token)
        }
        
        let localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event, token: token)
            return event
        }
        
        registrations[token] = Registration(
            shortcut: shortcut,
            action: action,
            globalMonitor: globalMonitor,
            localMonitor: localMonitor
        )
        
        return token
    }
    
    func unregister(_ token: Any) {
        guard let intToken = token as? Int,
              let registration = registrations[intToken] else { return }
        
        if let globalMonitor = registration.globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor = registration.localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        registrations.removeValue(forKey: intToken)
    }
    
    func unregisterAll() {
        for (_, registration) in registrations {
            if let globalMonitor = registration.globalMonitor {
                NSEvent.removeMonitor(globalMonitor)
            }
            if let localMonitor = registration.localMonitor {
                NSEvent.removeMonitor(localMonitor)
            }
        }
        registrations.removeAll()
    }
    
    private func handleKeyEvent(_ event: NSEvent, token: Int) {
        guard let registration = registrations[token] else { return }
        let shortcut = registration.shortcut
        
        let relevantFlags: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
        let eventFlags = event.modifierFlags.intersection(relevantFlags).rawValue
        
        if event.keyCode == shortcut.keyCode && eventFlags == shortcut.modifiers {
            DispatchQueue.main.async {
                registration.action()
            }
        }
    }
    
    deinit {
        unregisterAll()
    }
}

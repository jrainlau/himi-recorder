import Cocoa

/// Manages the menu bar status item and its dropdown menu.
final class StatusBarController {
    
    private var statusItem: NSStatusItem?
    private let menu = NSMenu()
    
    /// Callback when user clicks "开始录像".
    var onStartRecording: (() -> Void)?
    
    /// Callback when user clicks "设置".
    var onOpenSettings: (() -> Void)?
    
    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            button.image = createMenuBarIcon()
            button.toolTip = "Himi Recorder"
            button.setAccessibilityIdentifier("statusBarButton")
        }
        
        setupMenu()
        statusItem?.menu = menu
    }
    
    private func setupMenu() {
        menu.removeAllItems()
        
        let startItem = NSMenuItem(
            title: "开始录像",
            action: #selector(startRecordingAction),
            keyEquivalent: ""
        )
        startItem.target = self
        startItem.identifier = NSUserInterfaceItemIdentifier("menuStartRecording")
        menu.addItem(startItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let settingsItem = NSMenuItem(
            title: "设置",
            action: #selector(openSettingsAction),
            keyEquivalent: ","
        )
        settingsItem.target = self
        settingsItem.identifier = NSUserInterfaceItemIdentifier("menuSettings")
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(
            title: "退出",
            action: #selector(quitAction),
            keyEquivalent: "q"
        )
        quitItem.target = self
        quitItem.identifier = NSUserInterfaceItemIdentifier("menuQuit")
        menu.addItem(quitItem)
    }
    
    /// Create a custom-drawn menu bar icon: a mini camera/screen-record icon.
    /// Uses template rendering so it automatically adapts to light/dark mode.
    private func createMenuBarIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.black.set()
            
            // Draw a rounded-rect "screen" shape (like a monitor)
            let screenRect = NSRect(x: 1.5, y: 4.5, width: 15, height: 10)
            let screenPath = NSBezierPath(roundedRect: screenRect, xRadius: 1.5, yRadius: 1.5)
            screenPath.lineWidth = 1.3
            screenPath.stroke()
            
            // Draw a small "stand" / base line under the screen
            let standPath = NSBezierPath()
            standPath.move(to: NSPoint(x: 6, y: 4.5))
            standPath.line(to: NSPoint(x: 6, y: 2.5))
            standPath.line(to: NSPoint(x: 12, y: 2.5))
            standPath.line(to: NSPoint(x: 12, y: 4.5))
            standPath.lineWidth = 1.2
            standPath.stroke()
            
            // Draw a small filled "REC" circle inside the screen (recording indicator)
            NSColor.black.setFill()
            let recCircle = NSBezierPath(ovalIn: NSRect(x: 6.5, y: 7, width: 5, height: 5))
            recCircle.fill()
            
            return true
        }
        image.isTemplate = true
        return image
    }
    
    // MARK: - Actions
    
    @objc private func startRecordingAction() {
        onStartRecording?()
    }
    
    @objc private func openSettingsAction() {
        onOpenSettings?()
    }
    
    @objc private func quitAction() {
        NSApp.terminate(nil)
    }
}

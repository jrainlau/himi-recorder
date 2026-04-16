import Cocoa

/// A custom view that records keyboard shortcuts from the user.
final class ShortcutRecorderView: NSView {
    
    /// The currently recorded key combo.
    var keyCombo: KeyCombo? {
        didSet {
            updateLabel()
            onShortcutChanged?(keyCombo)
        }
    }
    
    /// Callback when the shortcut changes.
    var onShortcutChanged: ((KeyCombo?) -> Void)?
    
    private let label = NSTextField(labelWithString: "点击录入快捷键")
    private var isRecording = false
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        
        setAccessibilityIdentifier("shortcutRecorderView")
        
        label.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        label.textColor = .secondaryLabelColor
        label.alignment = .center
        label.isBezeled = false
        label.isEditable = false
        label.drawsBackground = false
        label.setAccessibilityIdentifier("shortcutLabel")
        addSubview(label)
    }
    
    override func layout() {
        super.layout()
        label.frame = bounds.insetBy(dx: 8, dy: 4)
    }
    
    override var acceptsFirstResponder: Bool { true }
    
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        isRecording = true
        label.stringValue = "请按快捷键..."
        label.textColor = .systemBlue
        layer?.borderColor = NSColor.systemBlue.cgColor
    }
    
    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }
        
        // ESC cancels recording
        if event.keyCode == 53 {
            isRecording = false
            updateLabel()
            return
        }
        
        // Delete clears the shortcut
        if event.keyCode == 51 {
            keyCombo = nil
            isRecording = false
            return
        }
        
        let relevantFlags: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
        let modifiers = event.modifierFlags.intersection(relevantFlags).rawValue
        
        // Require at least one modifier
        guard modifiers != 0 else { return }
        
        keyCombo = KeyCombo(keyCode: event.keyCode, modifiers: modifiers)
        isRecording = false
    }
    
    private func updateLabel() {
        if let combo = keyCombo {
            label.stringValue = combo.displayString
            label.textColor = .labelColor
        } else {
            label.stringValue = "点击录入快捷键"
            label.textColor = .secondaryLabelColor
        }
        layer?.borderColor = NSColor.separatorColor.cgColor
    }
}

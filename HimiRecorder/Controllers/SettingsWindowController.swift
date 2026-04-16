import Cocoa

/// Settings window for configuring frame rate, export path, and hotkeys.
final class SettingsWindowController: NSWindowController {
    
    private let settings: SettingsStoring
    
    /// Callback when settings change (to re-register hotkeys etc).
    var onSettingsChanged: (() -> Void)?
    
    private let frameRatePopup = NSPopUpButton()
    private let pathControl = NSPathControl()
    private let browseButton = NSButton(title: "浏览...", target: nil, action: nil)
    private let startShortcutRecorder = ShortcutRecorderView(frame: .zero)
    private let stopShortcutRecorder = ShortcutRecorderView(frame: .zero)
    
    init(settings: SettingsStoring) {
        self.settings = settings
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Himi Recorder 设置"
        window.center()
        window.isReleasedWhenClosed = false
        window.setAccessibilityIdentifier("settingsWindow")
        
        super.init(window: window)
        setupUI()
        loadSettings()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        guard let contentView = window?.contentView else { return }
        
        let padding: CGFloat = 20
        var y: CGFloat = contentView.bounds.height - padding
        
        // === Frame Rate Section ===
        y -= 20
        let fpsLabel = createLabel("视频帧率:", at: NSPoint(x: padding, y: y))
        contentView.addSubview(fpsLabel)
        
        y -= 30
        frameRatePopup.frame = NSRect(x: padding + 100, y: y, width: 120, height: 26)
        frameRatePopup.removeAllItems()
        frameRatePopup.addItems(withTitles: ["24 fps", "30 fps", "60 fps"])
        frameRatePopup.target = self
        frameRatePopup.action = #selector(frameRateChanged)
        frameRatePopup.setAccessibilityIdentifier("frameRatePopup")
        contentView.addSubview(frameRatePopup)
        
        let fpsDescLabel = createLabel("帧率:", at: NSPoint(x: padding, y: y + 3))
        contentView.addSubview(fpsDescLabel)
        
        // === Export Path Section ===
        y -= 50
        let pathLabel = createLabel("默认导出路径:", at: NSPoint(x: padding, y: y + 3))
        contentView.addSubview(pathLabel)
        
        y -= 30
        pathControl.frame = NSRect(x: padding, y: y, width: 300, height: 26)
        pathControl.pathStyle = .standard
        pathControl.isEditable = false
        pathControl.setAccessibilityIdentifier("pathControl")
        contentView.addSubview(pathControl)
        
        browseButton.frame = NSRect(x: padding + 310, y: y, width: 80, height: 26)
        browseButton.target = self
        browseButton.action = #selector(browseAction)
        browseButton.setAccessibilityIdentifier("browseButton")
        contentView.addSubview(browseButton)
        
        // === Start Recording Shortcut ===
        y -= 50
        let startLabel = createLabel("开始录像快捷键:", at: NSPoint(x: padding, y: y + 3))
        contentView.addSubview(startLabel)
        
        y -= 30
        startShortcutRecorder.frame = NSRect(x: padding + 120, y: y, width: 180, height: 28)
        startShortcutRecorder.setAccessibilityIdentifier("startShortcutRecorder")
        startShortcutRecorder.onShortcutChanged = { [weak self] combo in
            self?.settings.startRecordingShortcut = combo
            self?.onSettingsChanged?()
        }
        contentView.addSubview(startShortcutRecorder)
        
        let startDescLabel = createLabel("开始录像:", at: NSPoint(x: padding, y: y + 6))
        contentView.addSubview(startDescLabel)
        
        // === Stop Recording Shortcut ===
        y -= 45
        let stopLabel = createLabel("结束录像快捷键:", at: NSPoint(x: padding, y: y + 3))
        contentView.addSubview(stopLabel)
        
        y -= 30
        stopShortcutRecorder.frame = NSRect(x: padding + 120, y: y, width: 180, height: 28)
        stopShortcutRecorder.setAccessibilityIdentifier("stopShortcutRecorder")
        stopShortcutRecorder.onShortcutChanged = { [weak self] combo in
            self?.settings.stopRecordingShortcut = combo
            self?.onSettingsChanged?()
        }
        contentView.addSubview(stopShortcutRecorder)
        
        let stopDescLabel = createLabel("结束录像:", at: NSPoint(x: padding, y: y + 6))
        contentView.addSubview(stopDescLabel)
    }
    
    private func createLabel(_ text: String, at point: NSPoint) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        label.frame.origin = point
        label.sizeToFit()
        return label
    }
    
    private func loadSettings() {
        // Frame rate
        switch settings.frameRate {
        case 24: frameRatePopup.selectItem(at: 0)
        case 30: frameRatePopup.selectItem(at: 1)
        default: frameRatePopup.selectItem(at: 2) // 60 fps
        }
        
        // Export path
        if let path = settings.defaultExportPath {
            pathControl.url = URL(fileURLWithPath: path)
        }
        
        // Shortcuts
        startShortcutRecorder.keyCombo = settings.startRecordingShortcut
        stopShortcutRecorder.keyCombo = settings.stopRecordingShortcut
    }
    
    // MARK: - Actions
    
    @objc private func frameRateChanged() {
        let frameRates = [24, 30, 60]
        let index = frameRatePopup.indexOfSelectedItem
        guard index >= 0 && index < frameRates.count else { return }
        settings.frameRate = frameRates[index]
        onSettingsChanged?()
    }
    
    @objc private func browseAction() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "选择"
        
        panel.beginSheetModal(for: window!) { [weak self] response in
            if response == .OK, let url = panel.url {
                self?.settings.defaultExportPath = url.path
                self?.pathControl.url = url
                self?.onSettingsChanged?()
            }
        }
    }
    
    // MARK: - Public
    
    func showSettings() {
        loadSettings()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

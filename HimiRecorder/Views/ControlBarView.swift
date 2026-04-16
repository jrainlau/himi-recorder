import Cocoa

/// Floating control bar that shows below the selection area.
/// Displays size info, timer, and start/stop recording buttons.
final class ControlBarWindow: NSWindow {
    
    private let controlBarView: ControlBarView
    
    /// Callback for start recording button tap.
    var onStartRecording: (() -> Void)? {
        get { controlBarView.onStartRecording }
        set { controlBarView.onStartRecording = newValue }
    }
    
    /// Callback for stop recording button tap.
    var onStopRecording: (() -> Void)? {
        get { controlBarView.onStopRecording }
        set { controlBarView.onStopRecording = newValue }
    }
    
    init() {
        controlBarView = ControlBarView(frame: NSRect(x: 0, y: 0, width: 280, height: 40))
        
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 40),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        
        isOpaque = false
        backgroundColor = .clear
        level = .screenSaver + 1
        hasShadow = true
        contentView = controlBarView
        setAccessibilityIdentifier("controlBarWindow")
    }
    
    /// Position the control bar below the selection rect.
    /// `selectionNSRect` is in NS global screen coordinates (bottom-left origin).
    func positionBelow(selectionNSRect: CGRect) {
        let barWidth: CGFloat = 280
        let barHeight: CGFloat = 40
        let spacing: CGFloat = 12
        
        let centerX = selectionNSRect.midX - barWidth / 2
        let y = selectionNSRect.minY - barHeight - spacing
        
        setFrame(NSRect(x: centerX, y: y, width: barWidth, height: barHeight), display: true)
    }
    
    func setRecordingState(_ recording: Bool) {
        controlBarView.setRecordingState(recording)
    }
    
    func updateSizeLabel(width: Int, height: Int) {
        controlBarView.updateSizeLabel(width: width, height: height)
    }
    
    func updateTimer(seconds: Int) {
        controlBarView.updateTimer(seconds: seconds)
    }
}

/// The actual view content of the control bar.
final class ControlBarView: NSView {
    
    var onStartRecording: (() -> Void)?
    var onStopRecording: (() -> Void)?
    
    private let timerLabel = NSTextField(labelWithString: "00:00")
    private let actionButton = NSButton()
    private let sizeLabel = NSTextField(labelWithString: "")
    /// Red recording dot indicator
    private let recordingDot = NSView()
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
        layer?.cornerRadius = 8
        layer?.backgroundColor = NSColor.white.cgColor
        layer?.shadowColor = NSColor.black.withAlphaComponent(0.2).cgColor
        layer?.shadowOffset = CGSize(width: 0, height: -2)
        layer?.shadowRadius = 8
        layer?.shadowOpacity = 1.0
        
        setAccessibilityIdentifier("controlBarView")
        
        // Size label (left side)
        sizeLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        sizeLabel.textColor = NSColor.secondaryLabelColor
        sizeLabel.isBezeled = false
        sizeLabel.isEditable = false
        sizeLabel.drawsBackground = false
        sizeLabel.setAccessibilityIdentifier("sizeLabel")
        addSubview(sizeLabel)
        
        // Recording dot (red circle, visible only during recording)
        recordingDot.wantsLayer = true
        recordingDot.layer?.backgroundColor = NSColor.systemRed.cgColor
        recordingDot.layer?.cornerRadius = 4
        recordingDot.isHidden = true
        addSubview(recordingDot)
        
        // Timer label (shown next to the recording dot during recording)
        timerLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        timerLabel.textColor = NSColor.labelColor
        timerLabel.isBezeled = false
        timerLabel.isEditable = false
        timerLabel.drawsBackground = false
        timerLabel.setAccessibilityIdentifier("timerLabel")
        addSubview(timerLabel)
        
        // Action button
        actionButton.bezelStyle = .rounded
        actionButton.isBordered = false
        actionButton.wantsLayer = true
        actionButton.target = self
        actionButton.action = #selector(actionButtonClicked)
        actionButton.setAccessibilityIdentifier("actionButton")
        addSubview(actionButton)
        
        setRecordingState(false)
    }
    
    override func layout() {
        super.layout()
        
        let padding: CGFloat = 12
        let buttonWidth: CGFloat = 80
        let buttonHeight: CGFloat = 28
        
        // Action button always on the right
        actionButton.frame = CGRect(
            x: bounds.width - buttonWidth - padding,
            y: (bounds.height - buttonHeight) / 2,
            width: buttonWidth,
            height: buttonHeight
        )
        
        if isRecording {
            // Recording: [●  00:23  |  结束录制]
            // Recording dot
            let dotSize: CGFloat = 8
            recordingDot.frame = CGRect(
                x: padding,
                y: (bounds.height - dotSize) / 2,
                width: dotSize,
                height: dotSize
            )
            
            // Timer next to the dot
            timerLabel.sizeToFit()
            timerLabel.frame.origin = CGPoint(
                x: recordingDot.frame.maxX + 6,
                y: (bounds.height - timerLabel.frame.height) / 2
            )
        } else {
            // Not recording: [529 × 281  00:00  |  开始录制]
            sizeLabel.sizeToFit()
            sizeLabel.frame.origin = CGPoint(x: padding, y: (bounds.height - sizeLabel.frame.height) / 2)
            
            timerLabel.sizeToFit()
            timerLabel.frame.origin = CGPoint(
                x: actionButton.frame.minX - timerLabel.frame.width - 10,
                y: (bounds.height - timerLabel.frame.height) / 2
            )
        }
    }
    
    func setRecordingState(_ recording: Bool) {
        isRecording = recording
        
        if recording {
            actionButton.title = "结束录制"
            actionButton.layer?.backgroundColor = NSColor(calibratedRed: 1.0, green: 0.231, blue: 0.188, alpha: 1.0).cgColor
            actionButton.contentTintColor = .white
            actionButton.layer?.cornerRadius = 6
            timerLabel.textColor = NSColor.systemRed
            timerLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
            recordingDot.isHidden = false
            sizeLabel.isHidden = true
            startDotBlinking()
        } else {
            actionButton.title = "开始录制"
            actionButton.layer?.backgroundColor = NSColor(calibratedRed: 0.0, green: 0.478, blue: 1.0, alpha: 1.0).cgColor
            actionButton.contentTintColor = .white
            actionButton.layer?.cornerRadius = 6
            timerLabel.textColor = NSColor.secondaryLabelColor
            timerLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
            recordingDot.isHidden = true
            sizeLabel.isHidden = false
            stopDotBlinking()
        }
        
        needsLayout = true
    }
    
    func updateSizeLabel(width: Int, height: Int) {
        sizeLabel.stringValue = "\(width) × \(height)"
        needsLayout = true
    }
    
    func updateTimer(seconds: Int) {
        let minutes = seconds / 60
        let secs = seconds % 60
        timerLabel.stringValue = String(format: "%02d:%02d", minutes, secs)
        needsLayout = true
    }
    
    @objc private func actionButtonClicked() {
        if isRecording {
            onStopRecording?()
        } else {
            onStartRecording?()
        }
    }
    
    // MARK: - Dot Blinking Animation
    
    private func startDotBlinking() {
        let anim = CABasicAnimation(keyPath: "opacity")
        anim.fromValue = 1.0
        anim.toValue = 0.2
        anim.duration = 0.8
        anim.autoreverses = true
        anim.repeatCount = .infinity
        recordingDot.layer?.add(anim, forKey: "blink")
    }
    
    private func stopDotBlinking() {
        recordingDot.layer?.removeAnimation(forKey: "blink")
    }
}

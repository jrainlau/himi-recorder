import Cocoa

/// Full-screen window that shows a countdown (3, 2, 1) before recording.
final class CountdownWindow: NSWindow {
    
    private let countdownView: CountdownView
    
    /// Called when countdown finishes.
    var onCountdownComplete: (() -> Void)?
    
    init() {
        countdownView = CountdownView(frame: NSRect(x: 0, y: 0, width: 120, height: 120))
        
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 120, height: 120),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        
        isOpaque = false
        backgroundColor = .clear
        level = .screenSaver + 2
        hasShadow = false
        ignoresMouseEvents = true
        contentView = countdownView
        setAccessibilityIdentifier("countdownWindow")
    }
    
    /// Start the countdown centered on the given NS screen rect.
    func startCountdown(centeredOnNSRect nsRect: CGRect, completion: @escaping () -> Void) {
        onCountdownComplete = completion
        
        let size: CGFloat = 120
        let centerX = nsRect.midX - size / 2
        let centerY = nsRect.midY - size / 2
        setFrame(NSRect(x: centerX, y: centerY, width: size, height: size), display: true)
        
        makeKeyAndOrderFront(nil)
        
        countdownView.startCountdown { [weak self] in
            self?.orderOut(nil)
            self?.onCountdownComplete?()
        }
    }
}

/// View that displays the countdown number with animation.
final class CountdownView: NSView {
    
    private let numberLabel = NSTextField(labelWithString: "3")
    private var currentCount = 3
    private var timer: Timer?
    private var completion: (() -> Void)?
    
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
        layer?.cornerRadius = 60
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.7).cgColor
        
        setAccessibilityIdentifier("countdownView")
        
        numberLabel.font = NSFont.systemFont(ofSize: 64, weight: .bold)
        numberLabel.textColor = .white
        numberLabel.alignment = .center
        numberLabel.isBezeled = false
        numberLabel.isEditable = false
        numberLabel.drawsBackground = false
        numberLabel.setAccessibilityIdentifier("countdownNumber")
        addSubview(numberLabel)
    }
    
    override func layout() {
        super.layout()
        // Vertically and horizontally center the number label
        numberLabel.sizeToFit()
        let labelSize = numberLabel.fittingSize
        numberLabel.frame = CGRect(
            x: (bounds.width - labelSize.width) / 2,
            y: (bounds.height - labelSize.height) / 2,
            width: labelSize.width,
            height: labelSize.height
        )
    }
    
    /// Start the 3-2-1 countdown with animation.
    func startCountdown(completion: @escaping () -> Void) {
        self.completion = completion
        currentCount = 3
        numberLabel.stringValue = "3"
        
        animateNumber()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            self.currentCount -= 1
            
            if self.currentCount <= 0 {
                timer.invalidate()
                self.timer = nil
                self.completion?()
            } else {
                self.numberLabel.stringValue = "\(self.currentCount)"
                self.animateNumber()
            }
        }
    }
    
    /// Cancel the countdown.
    func cancelCountdown() {
        timer?.invalidate()
        timer = nil
    }
    
    private func animateNumber() {
        guard let layer = numberLabel.layer else { return }
        
        // Scale animation: 1.2x -> 1.0x
        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        scaleAnimation.fromValue = 1.2
        scaleAnimation.toValue = 1.0
        scaleAnimation.duration = 0.3
        scaleAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        
        // Opacity animation: 0 -> 1
        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
        opacityAnimation.fromValue = 0.5
        opacityAnimation.toValue = 1.0
        opacityAnimation.duration = 0.3
        
        layer.add(scaleAnimation, forKey: "scaleIn")
        layer.add(opacityAnimation, forKey: "fadeIn")
    }
}

import Cocoa
import AVKit
import AVFoundation

/// Dark-themed preview window with speed control and trim bar.
final class PreviewWindowController: NSWindowController {
    
    private var playerView: AVPlayerView!
    private var player: AVPlayer?
    private var videoURL: URL?
    private var timeObserver: Any?
    
    private let timerLabel = NSTextField(labelWithString: "00:00 / 00:00")
    private let exportButton = NSButton()
    private let cancelButton = NSButton()
    private let confirmButton = NSButton()
    private let speedButton = NSPopUpButton()
    private var trimView: TrimBarView!
    
    /// Callback when user confirms and wants to export.
    var onExport: ((URL) -> Void)?
    /// Callback when user cancels.
    var onCancel: (() -> Void)?
    
    private let availableSpeeds: [Float] = [0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0]
    private var selectedSpeed: Float = 1.0
    
    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Himi Recorder"
        window.center()
        window.minSize = NSSize(width: 480, height: 400)
        window.setAccessibilityIdentifier("previewWindow")
        
        super.init(window: window)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        guard let window = self.window else { return }
        
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = NSColor(calibratedRed: 0.118, green: 0.118, blue: 0.118, alpha: 1.0)
        
        let contentView = NSView(frame: window.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]
        window.contentView = contentView
        
        // Player view
        playerView = AVPlayerView(frame: .zero)
        playerView.controlsStyle = .minimal
        playerView.setAccessibilityIdentifier("playerView")
        contentView.addSubview(playerView)
        
        // Trim bar (between player and toolbar)
        trimView = TrimBarView(frame: .zero)
        trimView.onTrimChanged = { [weak self] startFraction, endFraction in
            self?.handleTrimChanged(startFraction: startFraction, endFraction: endFraction)
        }
        contentView.addSubview(trimView)
        
        // Bottom toolbar
        let toolbar = NSView(frame: .zero)
        toolbar.wantsLayer = true
        toolbar.layer?.backgroundColor = NSColor(calibratedRed: 0.165, green: 0.165, blue: 0.165, alpha: 1.0).cgColor
        toolbar.setAccessibilityIdentifier("previewToolbar")
        contentView.addSubview(toolbar)
        
        // Timer label
        timerLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        timerLabel.textColor = .white
        timerLabel.isBezeled = false
        timerLabel.isEditable = false
        timerLabel.drawsBackground = false
        timerLabel.setAccessibilityIdentifier("previewTimerLabel")
        toolbar.addSubview(timerLabel)
        
        // Speed popup button
        speedButton.removeAllItems()
        for speed in availableSpeeds {
            let title = speed == Float(Int(speed)) ? "\(Int(speed))x" : "\(speed)x"
            speedButton.addItem(withTitle: title)
        }
        speedButton.selectItem(at: 1) // Default 1x
        speedButton.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        speedButton.target = self
        speedButton.action = #selector(speedChanged)
        speedButton.setAccessibilityIdentifier("speedButton")
        toolbar.addSubview(speedButton)
        
        // Export button
        setupButton(exportButton, title: "导出", identifier: "exportButton", color: NSColor.systemBlue)
        exportButton.target = self
        exportButton.action = #selector(exportAction)
        toolbar.addSubview(exportButton)
        
        // Cancel button
        setupButton(cancelButton, title: "✕", identifier: "cancelButton", color: NSColor.systemGray)
        cancelButton.target = self
        cancelButton.action = #selector(cancelAction)
        toolbar.addSubview(cancelButton)
        
        // Confirm button
        setupButton(confirmButton, title: "✓", identifier: "confirmButton", color: NSColor.systemGreen)
        confirmButton.target = self
        confirmButton.action = #selector(confirmAction)
        toolbar.addSubview(confirmButton)
        
        setupLayout(contentView: contentView, toolbar: toolbar)
    }
    
    private func setupButton(_ button: NSButton, title: String, identifier: String, color: NSColor) {
        button.title = title
        button.bezelStyle = .rounded
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.backgroundColor = color.withAlphaComponent(0.8).cgColor
        button.layer?.cornerRadius = 4
        button.contentTintColor = .white
        button.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        button.setAccessibilityIdentifier(identifier)
    }
    
    private func setupLayout(contentView: NSView, toolbar: NSView) {
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        playerView.translatesAutoresizingMaskIntoConstraints = false
        trimView.translatesAutoresizingMaskIntoConstraints = false
        timerLabel.translatesAutoresizingMaskIntoConstraints = false
        speedButton.translatesAutoresizingMaskIntoConstraints = false
        exportButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        confirmButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Toolbar at bottom
            toolbar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            toolbar.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: 48),
            
            // Trim bar above toolbar
            trimView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            trimView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            trimView.bottomAnchor.constraint(equalTo: toolbar.topAnchor, constant: -4),
            trimView.heightAnchor.constraint(equalToConstant: 36),
            
            // Player view above trim bar
            playerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            playerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            playerView.bottomAnchor.constraint(equalTo: trimView.topAnchor, constant: -4),
            
            // Timer label - left
            timerLabel.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor, constant: 16),
            timerLabel.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            
            // Speed button - next to timer
            speedButton.leadingAnchor.constraint(equalTo: timerLabel.trailingAnchor, constant: 12),
            speedButton.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            speedButton.widthAnchor.constraint(equalToConstant: 60),
            
            // Confirm button - right
            confirmButton.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor, constant: -16),
            confirmButton.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            confirmButton.widthAnchor.constraint(equalToConstant: 36),
            confirmButton.heightAnchor.constraint(equalToConstant: 28),
            
            // Cancel button
            cancelButton.trailingAnchor.constraint(equalTo: confirmButton.leadingAnchor, constant: -8),
            cancelButton.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            cancelButton.widthAnchor.constraint(equalToConstant: 36),
            cancelButton.heightAnchor.constraint(equalToConstant: 28),
            
            // Export button
            exportButton.trailingAnchor.constraint(equalTo: cancelButton.leadingAnchor, constant: -8),
            exportButton.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            exportButton.widthAnchor.constraint(equalToConstant: 56),
            exportButton.heightAnchor.constraint(equalToConstant: 28),
        ])
    }
    
    // MARK: - Public
    
    func loadVideo(at url: URL) {
        self.videoURL = url
        player = AVPlayer(url: url)
        playerView.player = player
        
        // Set up trim bar with video duration
        let asset = AVAsset(url: url)
        Task {
            if let duration = try? await asset.load(.duration), duration.seconds > 0 && !duration.seconds.isNaN {
                await MainActor.run {
                    self.trimView.totalDuration = duration.seconds
                }
            }
        }
        
        setupTimeObserver()
        
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    // MARK: - Speed
    
    @objc private func speedChanged() {
        let index = speedButton.indexOfSelectedItem
        guard index >= 0 && index < availableSpeeds.count else { return }
        selectedSpeed = availableSpeeds[index]
        player?.rate = selectedSpeed
    }
    
    // MARK: - Trim
    
    private func handleTrimChanged(startFraction: CGFloat, endFraction: CGFloat) {
        guard let item = player?.currentItem else { return }
        let duration = item.duration.seconds
        guard !duration.isNaN && duration > 0 else { return }
        
        let startTime = duration * Double(startFraction)
        player?.seek(to: CMTime(seconds: startTime, preferredTimescale: 600))
    }
    
    // MARK: - Time Observer
    
    private func setupTimeObserver() {
        guard let player = player else { return }
        
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.updateTimeLabel()
            self?.updateTrimPlayhead()
        }
    }
    
    private func updateTimeLabel() {
        guard let player = player, let item = player.currentItem else { return }
        
        let current = player.currentTime().seconds
        let total = item.duration.seconds
        guard !total.isNaN && !total.isInfinite else { return }
        
        timerLabel.stringValue = "\(formatTime(current)) / \(formatTime(total))"
    }
    
    private func updateTrimPlayhead() {
        guard let player = player, let item = player.currentItem else { return }
        let total = item.duration.seconds
        let current = player.currentTime().seconds
        guard !total.isNaN && total > 0 else { return }
        
        trimView.playheadFraction = CGFloat(current / total)
        
        // Loop within trim range
        let endTime = total * Double(trimView.endFraction)
        if current >= endTime {
            let startTime = total * Double(trimView.startFraction)
            player.seek(to: CMTime(seconds: startTime, preferredTimescale: 600))
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let s = max(0, seconds)
        let mins = Int(s) / 60
        let secs = Int(s) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
    
    // MARK: - Actions
    
    @objc private func exportAction() {
        guard let videoURL = videoURL else { return }
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.mpeg4Movie]
        savePanel.nameFieldStringValue = "recording.mp4"
        savePanel.canCreateDirectories = true
        
        savePanel.beginSheetModal(for: window!) { [weak self] response in
            guard let self = self, response == .OK, let destinationURL = savePanel.url else { return }
            self.exportTrimmedVideo(from: videoURL, to: destinationURL)
        }
    }
    
    @objc private func cancelAction() {
        cleanupAndClose()
        onCancel?()
    }
    
    @objc private func confirmAction() {
        guard let videoURL = videoURL else { return }
        
        let needsTrim = trimView.startFraction > 0.001 || trimView.endFraction < 0.999
        let needsSpeed = abs(selectedSpeed - 1.0) > 0.01
        
        if !needsTrim && !needsSpeed {
            // No edits, copy original to clipboard directly
            copyVideoToClipboard(url: videoURL)
        } else {
            // Export edited video to temp file, then copy to clipboard
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("himi_clipboard_\(Int(Date().timeIntervalSince1970)).mp4")
            exportTrimmedVideo(from: videoURL, to: tempURL, completion: { [weak self] resultURL in
                self?.copyVideoToClipboard(url: resultURL)
            })
        }
    }
    
    /// Copy a video file to the system pasteboard so it can be pasted in IM apps.
    private func copyVideoToClipboard(url: URL) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([url as NSURL])
        
        // Also set file promise for broader compatibility
        pasteboard.setString(url.path, forType: .fileURL)
        
        // Show brief confirmation
        let alert = NSAlert()
        alert.messageText = "已复制到剪贴板"
        alert.informativeText = "视频已复制，可直接粘贴到微信等 IM 软件发送。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "好")
        alert.beginSheetModal(for: window!) { [weak self] _ in
            self?.cleanupAndClose()
        }
    }
    
    /// Export the video with trim and speed applied.
    /// If `completion` is provided, calls it with the exported URL instead of the default onExport behavior.
    private func exportTrimmedVideo(from source: URL, to destination: URL, completion: ((URL) -> Void)? = nil) {
        let asset = AVAsset(url: source)
        
        Task {
            do {
                let duration = try await asset.load(.duration)
                let totalSeconds = duration.seconds
                guard !totalSeconds.isNaN && totalSeconds > 0 else {
                    await MainActor.run { self.showExportError("视频时长无效") }
                    return
                }
                
                let startTime = CMTime(seconds: totalSeconds * Double(trimView.startFraction), preferredTimescale: 600)
                let endTime = CMTime(seconds: totalSeconds * Double(trimView.endFraction), preferredTimescale: 600)
                let timeRange = CMTimeRange(start: startTime, end: endTime)
                
                let needsTrim = trimView.startFraction > 0.001 || trimView.endFraction < 0.999
                let needsSpeed = abs(selectedSpeed - 1.0) > 0.01
                
                if !needsTrim && !needsSpeed {
                    await MainActor.run {
                        if let completion = completion {
                            // For clipboard: just use the source directly
                            completion(source)
                        } else {
                            self.simpleCopy(from: source, to: destination)
                        }
                    }
                    return
                }
                
                let composition = AVMutableComposition()
                
                guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
                    await MainActor.run { self.showExportError("无法读取视频轨道") }
                    return
                }
                
                let compositionVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
                try compositionVideoTrack?.insertTimeRange(timeRange, of: videoTrack, at: .zero)
                
                if needsSpeed {
                    let trimDuration = CMTimeSubtract(endTime, startTime)
                    let scaledDuration = CMTimeMultiplyByFloat64(trimDuration, multiplier: Float64(1.0 / selectedSpeed))
                    compositionVideoTrack?.scaleTimeRange(
                        CMTimeRange(start: .zero, duration: trimDuration),
                        toDuration: scaledDuration
                    )
                }
                
                if let audioTrack = try? await asset.loadTracks(withMediaType: .audio).first {
                    let compositionAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
                    try compositionAudioTrack?.insertTimeRange(timeRange, of: audioTrack, at: .zero)
                    
                    if needsSpeed {
                        let trimDuration = CMTimeSubtract(endTime, startTime)
                        let scaledDuration = CMTimeMultiplyByFloat64(trimDuration, multiplier: Float64(1.0 / selectedSpeed))
                        compositionAudioTrack?.scaleTimeRange(
                            CMTimeRange(start: .zero, duration: trimDuration),
                            toDuration: scaledDuration
                        )
                    }
                }
                
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                
                guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
                    await MainActor.run { self.showExportError("无法创建导出器") }
                    return
                }
                
                exporter.outputURL = destination
                exporter.outputFileType = .mp4
                
                await exporter.export()
                
                if exporter.status == .completed {
                    await MainActor.run {
                        if let completion = completion {
                            completion(destination)
                        } else {
                            self.onExport?(destination)
                            self.cleanupAndClose()
                        }
                    }
                } else {
                    let errorMsg = exporter.error?.localizedDescription ?? "未知错误"
                    await MainActor.run { self.showExportError(errorMsg) }
                }
                
            } catch {
                await MainActor.run { self.showExportError(error.localizedDescription) }
            }
        }
    }
    
    private func simpleCopy(from source: URL, to destination: URL) {
        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: source, to: destination)
            onExport?(destination)
            cleanupAndClose()
        } catch {
            showExportError(error.localizedDescription)
        }
    }
    
    private func showExportError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "导出失败"
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.runModal()
    }
    
    private func cleanupAndClose() {
        player?.pause()
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        player = nil
        close()
    }
}

// MARK: - Trim Bar View (QuickTime-style)

/// A horizontal bar with two draggable handles for trimming video start/end.
final class TrimBarView: NSView {
    
    /// Called when trim handles change. Parameters: (startFraction, endFraction) in 0...1
    var onTrimChanged: ((CGFloat, CGFloat) -> Void)?
    
    /// Current playhead position as a fraction 0...1
    var playheadFraction: CGFloat = 0 {
        didSet { needsDisplay = true }
    }
    
    /// Start trim position as fraction 0...1
    private(set) var startFraction: CGFloat = 0.0
    /// End trim position as fraction 0...1
    private(set) var endFraction: CGFloat = 1.0
    
    /// Total video duration (for display)
    var totalDuration: Double = 0
    
    private let handleWidth: CGFloat = 12
    private var draggingHandle: DragHandle = .none
    
    private enum DragHandle {
        case none, start, end
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        
        let trackRect = bounds.insetBy(dx: handleWidth, dy: 4)
        
        // Background track (dark)
        ctx.setFillColor(NSColor(white: 0.2, alpha: 1).cgColor)
        ctx.fill(trackRect)
        
        // Active region (yellow/gold, like QuickTime)
        let activeX = trackRect.minX + trackRect.width * startFraction
        let activeWidth = trackRect.width * (endFraction - startFraction)
        let activeRect = CGRect(x: activeX, y: trackRect.minY, width: activeWidth, height: trackRect.height)
        ctx.setFillColor(NSColor(calibratedRed: 0.95, green: 0.8, blue: 0.2, alpha: 0.4).cgColor)
        ctx.fill(activeRect)
        
        // Dimmed regions outside trim
        ctx.setFillColor(NSColor(white: 0, alpha: 0.5).cgColor)
        let leftDimRect = CGRect(x: trackRect.minX, y: trackRect.minY, width: activeX - trackRect.minX, height: trackRect.height)
        ctx.fill(leftDimRect)
        let rightDimRect = CGRect(x: activeRect.maxX, y: trackRect.minY, width: trackRect.maxX - activeRect.maxX, height: trackRect.height)
        ctx.fill(rightDimRect)
        
        // Start handle
        let startHandleRect = CGRect(x: activeX - handleWidth / 2, y: bounds.minY, width: handleWidth, height: bounds.height)
        ctx.setFillColor(NSColor(calibratedRed: 0.95, green: 0.75, blue: 0.1, alpha: 1).cgColor)
        let startPath = CGPath(roundedRect: startHandleRect, cornerWidth: 3, cornerHeight: 3, transform: nil)
        ctx.addPath(startPath)
        ctx.fillPath()
        
        // End handle
        let endX = trackRect.minX + trackRect.width * endFraction
        let endHandleRect = CGRect(x: endX - handleWidth / 2, y: bounds.minY, width: handleWidth, height: bounds.height)
        ctx.addPath(CGPath(roundedRect: endHandleRect, cornerWidth: 3, cornerHeight: 3, transform: nil))
        ctx.fillPath()
        
        // Playhead (thin white line)
        let playX = trackRect.minX + trackRect.width * playheadFraction
        ctx.setStrokeColor(NSColor.white.cgColor)
        ctx.setLineWidth(2)
        ctx.move(to: CGPoint(x: playX, y: bounds.minY + 2))
        ctx.addLine(to: CGPoint(x: playX, y: bounds.maxY - 2))
        ctx.strokePath()
    }
    
    // MARK: - Mouse Events
    
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let trackRect = bounds.insetBy(dx: handleWidth, dy: 0)
        
        let startX = trackRect.minX + trackRect.width * startFraction
        let endX = trackRect.minX + trackRect.width * endFraction
        
        if abs(point.x - startX) < handleWidth {
            draggingHandle = .start
        } else if abs(point.x - endX) < handleWidth {
            draggingHandle = .end
        } else {
            draggingHandle = .none
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard draggingHandle != .none else { return }
        
        let point = convert(event.locationInWindow, from: nil)
        let trackRect = bounds.insetBy(dx: handleWidth, dy: 0)
        
        let fraction = max(0, min(1, (point.x - trackRect.minX) / trackRect.width))
        
        switch draggingHandle {
        case .start:
            startFraction = min(fraction, endFraction - 0.01)
        case .end:
            endFraction = max(fraction, startFraction + 0.01)
        case .none:
            break
        }
        
        needsDisplay = true
        onTrimChanged?(startFraction, endFraction)
    }
    
    override func mouseUp(with event: NSEvent) {
        draggingHandle = .none
    }
}

import Cocoa
import CoreMedia

class AppDelegate: NSObject, NSApplicationDelegate {
    
    private let statusBarController = StatusBarController()
    private let settingsManager = SettingsManager()
    private let hotKeyManager = HotKeyManager()
    
    private var selectionController: SelectionOverlayWindowController?
    private var controlBarWindow: ControlBarWindow?
    private var countdownWindow: CountdownWindow?
    private var recordingBorderWindow: NSWindow?
    private var previewController: PreviewWindowController?
    private var settingsController: SettingsWindowController?
    
    private var captureEngine: ScreenCaptureEngine?
    private var videoWriter: VideoWriter?
    
    private var recordingTimer: Timer?
    private var recordingSeconds: Int = 0
    private var escMonitor: Any?
    /// The selection rect in NS global screen coordinates (bottom-left origin).
    private var currentSelectionNSRect: CGRect = .zero
    /// The NSScreen where the selection was made.
    private var currentSelectionScreen: NSScreen?
    private var tempVideoURL: URL?
    
    // MARK: - App Lifecycle
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        checkPermissions()
        setupStatusBar()
        setupHotKeys()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        hotKeyManager.unregisterAll()
        captureEngine?.stopCapture()
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    // MARK: - Coordinate Conversion
    
    /// Convert NS global screen coordinates (bottom-left origin) to
    /// CG/Quartz display coordinates (top-left origin) for CGWindowListCreateImage.
    private func nsToCGRect(_ nsRect: CGRect) -> CGRect {
        // In the NS coordinate system, the main screen (with menu bar) has origin at bottom-left.
        // In the CG coordinate system, the main screen has origin at top-left.
        // The main screen is the one whose origin is (0, 0) in NS coordinates.
        guard let mainScreen = NSScreen.screens.first else {
            return nsRect
        }
        let mainHeight = mainScreen.frame.height
        // NS: origin.y is from bottom; CG: origin.y is from top
        let cgY = mainHeight - nsRect.maxY
        return CGRect(x: nsRect.origin.x, y: cgY, width: nsRect.width, height: nsRect.height)
    }
    
    // MARK: - Setup
    
    private func checkPermissions() {
        // Pre-authorize ScreenCaptureKit at launch so the permission dialog
        // appears immediately, not during recording.
        PermissionHelper.preauthorizeScreenCaptureKit()
    }
    
    private func setupStatusBar() {
        statusBarController.setup()
        
        statusBarController.onStartRecording = { [weak self] in
            self?.startSelectionFlow()
        }
        
        statusBarController.onOpenSettings = { [weak self] in
            self?.openSettings()
        }
    }
    
    private func setupHotKeys() {
        registerHotKeys()
    }
    
    private func registerHotKeys() {
        hotKeyManager.unregisterAll()
        
        if let startCombo = settingsManager.startRecordingShortcut {
            _ = hotKeyManager.register(shortcut: startCombo) { [weak self] in
                self?.startSelectionFlow()
            }
        }
        
        if let stopCombo = settingsManager.stopRecordingShortcut {
            _ = hotKeyManager.register(shortcut: stopCombo) { [weak self] in
                self?.stopRecording()
            }
        }
    }
    
    // MARK: - Recording Flow
    
    /// Step 1: Show selection overlay on all screens
    private func startSelectionFlow() {
        let controller = SelectionOverlayWindowController()
        controller.onSelectionComplete = { [weak self] nsRect, screen in
            self?.handleSelectionComplete(nsRect, screen: screen)
        }
        controller.onSelectionCancelled = { [weak self] in
            self?.cancelRecording()
        }
        controller.showOverlay()
        self.selectionController = controller
        
        // Monitor ESC key globally so it works even after selection overlay
        // loses first responder (e.g., when control bar is shown)
        removeEscMonitor()
        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // ESC
                self?.cancelRecording()
                return nil // consume the event
            }
            return event
        }
    }
    
    /// Step 2: Selection complete, show control bar below the selection area
    private func handleSelectionComplete(_ nsRect: CGRect, screen: NSScreen) {
        currentSelectionNSRect = nsRect
        currentSelectionScreen = screen
        
        let controlBar = ControlBarWindow()
        controlBar.updateSizeLabel(width: Int(nsRect.width), height: Int(nsRect.height))
        controlBar.updateTimer(seconds: 0)
        
        controlBar.onStartRecording = { [weak self] in
            self?.startCountdown()
        }
        controlBar.onStopRecording = { [weak self] in
            self?.stopRecording()
        }
        
        // Position control bar below the selection rect (both in NS coords)
        controlBar.positionBelow(selectionNSRect: nsRect)
        controlBar.orderFront(nil)
        
        self.controlBarWindow = controlBar
    }
    
    /// Step 3: Start countdown
    private func startCountdown() {
        let countdown = CountdownWindow()
        // Center the countdown on the selection rect (NS coordinates)
        countdown.startCountdown(centeredOnNSRect: currentSelectionNSRect) { [weak self] in
            self?.beginRecording()
        }
        self.countdownWindow = countdown
    }
    
    /// Step 4: Begin actual recording
    private func beginRecording() {
        countdownWindow?.orderOut(nil)
        countdownWindow = nil
        
        // Convert NS rect to CG rect for screen capture
        let cgRect = nsToCGRect(currentSelectionNSRect)
        
        guard cgRect.width > 0 && cgRect.height > 0 else {
            print("[AppDelegate] Invalid selection rect")
            return
        }
        
        // Switch overlay to a thin recording border (keeps the border visible, removes the dimming)
        recordingBorderWindow = selectionController?.switchToRecordingBorder()
        
        // Create temp file — use .tmp extension during recording to avoid
        // detection by tools that scan open file descriptors for video extensions.
        // AVAssetWriter requires a file extension it can infer the format from,
        // so we still write with .mp4 in the filename but wrapped as .tmp;
        // the actual container format is determined by AVAssetWriter's fileType
        // parameter, not the extension. We rename to .mp4 after finishWriting.
        let tempDir = FileManager.default.temporaryDirectory
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd_HHmmss"
        let stamp = df.string(from: Date())
        let tempURL = tempDir.appendingPathComponent("HimiRecorder_\(stamp).tmp")
        self.tempVideoURL = tempURL
        
        // Use estimated Retina dimensions for the video writer
        // The actual captured frame may vary slightly, but VideoWriter handles scaling
        let captureWidth = Int(cgRect.width * 2)  // Retina 2x
        let captureHeight = Int(cgRect.height * 2)
        
        print("[AppDelegate] Starting recording: CG rect=\(cgRect), video=\(captureWidth)x\(captureHeight)")
        
        let writer = VideoWriter()
        do {
            try writer.startWriting(
                to: tempURL,
                width: captureWidth,
                height: captureHeight,
                frameRate: settingsManager.frameRate
            )
        } catch {
            print("[AppDelegate] Failed to start video writer: \(error)")
            return
        }
        self.videoWriter = writer
        
        // Setup capture engine (uses ScreenCaptureKit on macOS 14+)
        let engine = ScreenCaptureEngine()
        engine.captureRect = cgRect
        engine.frameRate = settingsManager.frameRate
        
        engine.onFrameCaptured = { [weak self] image, time in
            guard let self = self else { return }
            do {
                try self.videoWriter?.appendFrame(image, at: time)
            } catch {
                print("[AppDelegate] Failed to append frame: \(error)")
            }
        }
        
        engine.onError = { [weak self] error in
            print("[AppDelegate] Capture error: \(error)")
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "录制启动失败"
                alert.informativeText = "\(error.localizedDescription)\n\n请确认已在「系统设置 → 隐私与安全性 → 屏幕录制」中授权本应用，并重启应用。"
                alert.alertStyle = .critical
                alert.runModal()
                
                // Clean up
                self?.captureEngine?.stopCapture()
                self?.captureEngine = nil
                self?.videoWriter = nil
                self?.controlBarWindow?.setRecordingState(false)
            }
        }
        
        // Only start the recording timer AFTER ScreenCaptureKit setup is complete
        engine.onCaptureStarted = { [weak self] in
            guard let self = self else { return }
            print("[AppDelegate] Capture engine started, beginning timer")
            self.controlBarWindow?.setRecordingState(true)
            self.recordingSeconds = 0
            self.recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                self.recordingSeconds += 1
                self.controlBarWindow?.updateTimer(seconds: self.recordingSeconds)
            }
        }
        
        self.captureEngine = engine
        engine.startCapture()
    }
    
    /// Step 5: Stop recording
    private func stopRecording() {
        captureEngine?.stopCapture()
        captureEngine = nil
        
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        controlBarWindow?.orderOut(nil)
        controlBarWindow = nil
        recordingBorderWindow?.orderOut(nil)
        recordingBorderWindow = nil
        selectionController?.dismissOverlay()
        selectionController = nil
        
        removeEscMonitor()
        
        guard let writer = videoWriter, let _ = tempVideoURL else { return }
        
        writer.finishWriting { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let tmpURL):
                    // Rename .tmp → .mp4 now that writing is complete
                    let mp4URL = tmpURL.deletingPathExtension().appendingPathExtension("mp4")
                    try? FileManager.default.moveItem(at: tmpURL, to: mp4URL)
                    self?.tempVideoURL = mp4URL
                    self?.showPreview(url: mp4URL)
                case .failure(let error):
                    print("[AppDelegate] Failed to finish writing: \(error)")
                    let alert = NSAlert()
                    alert.messageText = "录制失败"
                    alert.informativeText = error.localizedDescription
                    alert.alertStyle = .critical
                    alert.runModal()
                }
            }
        }
        self.videoWriter = nil
    }
    
    /// Step 6: Show preview
    private func showPreview(url: URL) {
        let preview = PreviewWindowController()
        preview.onExport = { [weak self] exportedURL in
            print("[AppDelegate] Video exported to: \(exportedURL.path)")
            self?.cleanupTempFile()
        }
        preview.onCancel = { [weak self] in
            self?.cleanupTempFile()
        }
        preview.loadVideo(at: url)
        self.previewController = preview
    }
    
    // MARK: - Settings
    
    private func openSettings() {
        if settingsController == nil {
            settingsController = SettingsWindowController(settings: settingsManager)
            settingsController?.onSettingsChanged = { [weak self] in
                self?.registerHotKeys()
            }
        }
        settingsController?.showSettings()
    }
    
    // MARK: - Helpers
    
    /// Cancel the entire recording flow from any stage (selection, countdown, or recording).
    /// Triggered by pressing ESC at any point after startSelectionFlow().
    func cancelRecording() {
        // Stop capture if running
        captureEngine?.stopCapture()
        captureEngine = nil
        
        // Stop recording timer
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingSeconds = 0
        
        // Discard any partially-written video
        if let writer = videoWriter {
            writer.finishWriting { [weak self] _ in
                self?.cleanupTempFile()
            }
            videoWriter = nil
        }
        
        // Close all UI
        countdownWindow?.orderOut(nil)
        countdownWindow = nil
        controlBarWindow?.orderOut(nil)
        controlBarWindow = nil
        recordingBorderWindow?.orderOut(nil)
        recordingBorderWindow = nil
        selectionController?.dismissOverlay()
        selectionController = nil
        
        // Remove ESC monitor
        removeEscMonitor()
    }
    
    private func removeEscMonitor() {
        if let monitor = escMonitor {
            NSEvent.removeMonitor(monitor)
            escMonitor = nil
        }
    }
    
    private func cleanupTempFile() {
        if let url = tempVideoURL {
            try? FileManager.default.removeItem(at: url)
            tempVideoURL = nil
        }
    }
}

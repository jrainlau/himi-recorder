import Cocoa

/// Manages overlay windows for area selection across ALL screens.
final class SelectionOverlayWindowController {
    
    private var overlayWindows: [NSWindow] = []
    private var activeOverlayView: SelectionOverlayView?
    private var activeScreen: NSScreen?
    private var activeWindow: NSWindow?
    
    /// Called when user finishes selecting a region.
    /// Passes the selected rect in **NS global screen coordinates** (bottom-left origin)
    /// and the screen where the selection was made.
    var onSelectionComplete: ((CGRect, NSScreen) -> Void)?
    
    /// Called when user cancels selection (ESC key).
    var onSelectionCancelled: (() -> Void)?
    
    /// Show the overlay on ALL screens so user can select on any monitor.
    func showOverlay() {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }
        
        for screen in screens {
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            window.level = .screenSaver
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.ignoresMouseEvents = false
            window.acceptsMouseMovedEvents = true
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.setAccessibilityIdentifier("selectionOverlayWindow")
            
            let view = SelectionOverlayView(frame: CGRect(origin: .zero, size: screen.frame.size))
            view.onSelectionComplete = { [weak self] viewRect in
                self?.handleSelectionComplete(viewRect: viewRect, view: view, window: window, screen: screen)
            }
            view.onCancelled = { [weak self] in
                self?.dismissOverlay()
                self?.onSelectionCancelled?()
            }
            
            window.contentView = view
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(view)
            
            overlayWindows.append(window)
        }
        
        NSCursor.crosshair.push()
    }
    
    private func handleSelectionComplete(viewRect: CGRect, view: SelectionOverlayView, window: NSWindow, screen: NSScreen) {
        activeOverlayView = view
        activeScreen = screen
        activeWindow = window
        
        // Convert view coordinates -> window coordinates -> NS global screen coordinates
        let windowRect = view.convert(viewRect, to: nil)
        let nsScreenRect = window.convertToScreen(windowRect)
        
        // Pass NS screen coordinates (bottom-left origin) to the delegate.
        // The AppDelegate will convert to CG coordinates where needed.
        onSelectionComplete?(nsScreenRect, screen)
    }
    
    /// Dismiss all overlay windows.
    func dismissOverlay() {
        NSCursor.pop()
        for window in overlayWindows {
            window.orderOut(nil)
        }
        overlayWindows.removeAll()
        activeOverlayView = nil
        activeWindow = nil
        activeScreen = nil
    }
    
    /// Switch to a minimal "recording border" mode:
    /// dismiss all overlay windows except keep a thin border window around the selection.
    /// Returns the border window so the caller can manage it.
    func switchToRecordingBorder() -> NSWindow? {
        guard let view = activeOverlayView, let _ = activeScreen else { return nil }
        
        let viewRect = view.selectionRect
        guard let window = activeWindow else { return nil }
        
        let windowRect = view.convert(viewRect, to: nil)
        let nsScreenRect = window.convertToScreen(windowRect)
        
        // Dismiss all overlay windows
        NSCursor.pop()
        for w in overlayWindows {
            w.orderOut(nil)
        }
        overlayWindows.removeAll()
        activeOverlayView = nil
        activeWindow = nil
        activeScreen = nil
        
        // Create a thin border-only window around the selection area
        let borderInset: CGFloat = 2
        let borderWindow = NSWindow(
            contentRect: nsScreenRect.insetBy(dx: -borderInset, dy: -borderInset),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        borderWindow.isOpaque = false
        borderWindow.backgroundColor = .clear
        borderWindow.level = .screenSaver + 1
        borderWindow.hasShadow = false
        borderWindow.ignoresMouseEvents = true
        borderWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        borderWindow.setAccessibilityIdentifier("recordingBorderWindow")
        
        let borderView = RecordingBorderView(frame: CGRect(origin: .zero, size: borderWindow.frame.size))
        borderWindow.contentView = borderView
        borderWindow.orderFront(nil)
        
        return borderWindow
    }
    
    /// Get the current selection rect in view coordinates.
    var selectionRect: CGRect? {
        return activeOverlayView?.selectionRect
    }
}

// MARK: - Recording Border View

/// A simple view that draws a colored border to indicate the recording area.
final class RecordingBorderView: NSView {
    
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
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        // Draw a red border to indicate recording
        let borderWidth: CGFloat = 2
        let borderRect = bounds.insetBy(dx: borderWidth / 2, dy: borderWidth / 2)
        context.setStrokeColor(NSColor.systemRed.cgColor)
        context.setLineWidth(borderWidth)
        context.stroke(borderRect)
    }
}

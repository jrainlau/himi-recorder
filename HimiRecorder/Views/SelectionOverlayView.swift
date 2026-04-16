import Cocoa

/// The main selection overlay view that handles drawing and mouse interaction.
/// Draws a semi-transparent overlay with a cutout for the selected region,
/// blue border, and 8 drag handles.
final class SelectionOverlayView: NSView {
    
    // MARK: - Public
    
    var onSelectionComplete: ((CGRect) -> Void)?
    var onCancelled: (() -> Void)?
    
    /// The current selection rectangle in view coordinates.
    private(set) var selectionRect: CGRect = .zero
    
    // MARK: - Constants
    
    private let overlayColor = NSColor.black.withAlphaComponent(0.3)
    private let borderColor = NSColor(calibratedRed: 0.0, green: 0.478, blue: 1.0, alpha: 1.0) // #007AFF
    private let borderWidth: CGFloat = 1.5
    private let handleRadius: CGFloat = 4.0
    private let handleBorderWidth: CGFloat = 1.0
    private let minimumSelectionSize: CGFloat = 20.0
    
    // MARK: - State
    
    private enum InteractionState {
        case idle
        case drawing(startPoint: NSPoint)
        case moving(startPoint: NSPoint, originalRect: CGRect)
        case resizing(handle: HandlePosition, startPoint: NSPoint, originalRect: CGRect)
    }
    
    private var state: InteractionState = .idle
    private var hasSelection: Bool { selectionRect.width > 0 && selectionRect.height > 0 }
    
    // MARK: - Handle Positions
    
    enum HandlePosition: Int, CaseIterable {
        case topLeft, topCenter, topRight
        case middleLeft, middleRight
        case bottomLeft, bottomCenter, bottomRight
    }
    
    // MARK: - Init
    
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
        setAccessibilityIdentifier("selectionOverlayView")
    }
    
    override var acceptsFirstResponder: Bool { true }
    
    // MARK: - Drawing
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        // Draw semi-transparent overlay
        context.setFillColor(overlayColor.cgColor)
        context.fill(bounds)
        
        guard hasSelection else { return }
        
        // Cut out the selection area (make it transparent)
        context.setBlendMode(.clear)
        context.fill(selectionRect)
        context.setBlendMode(.normal)
        
        // Draw blue border
        context.setStrokeColor(borderColor.cgColor)
        context.setLineWidth(borderWidth)
        context.stroke(selectionRect)
        
        // Draw size label
        drawSizeLabel(context: context)
        
        // Draw 8 handles
        for position in HandlePosition.allCases {
            drawHandle(at: handlePoint(for: position), context: context)
        }
    }
    
    private func drawHandle(at point: CGPoint, context: CGContext) {
        let handleRect = CGRect(
            x: point.x - handleRadius,
            y: point.y - handleRadius,
            width: handleRadius * 2,
            height: handleRadius * 2
        )
        
        // White fill
        context.setFillColor(NSColor.white.cgColor)
        context.fillEllipse(in: handleRect)
        
        // Blue border
        context.setStrokeColor(borderColor.cgColor)
        context.setLineWidth(handleBorderWidth)
        context.strokeEllipse(in: handleRect)
    }
    
    private func drawSizeLabel(context: CGContext) {
        let width = Int(selectionRect.width)
        let height = Int(selectionRect.height)
        let text = "\(width) × \(height)"
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let textSize = (text as NSString).size(withAttributes: attributes)
        let padding: CGFloat = 6.0
        let labelWidth = textSize.width + padding * 2
        let labelHeight = textSize.height + padding
        
        let labelX = selectionRect.minX
        let labelY = selectionRect.maxY + 6
        let labelRect = CGRect(x: labelX, y: labelY, width: labelWidth, height: labelHeight)
        
        // Background
        let bgPath = NSBezierPath(roundedRect: labelRect, xRadius: 4, yRadius: 4)
        NSColor.black.withAlphaComponent(0.7).setFill()
        bgPath.fill()
        
        // Text
        let textPoint = NSPoint(x: labelRect.minX + padding, y: labelRect.minY + padding / 2)
        (text as NSString).draw(at: textPoint, withAttributes: attributes)
    }
    
    // MARK: - Handle Geometry
    
    /// Returns the center point for a given handle position.
    func handlePoint(for position: HandlePosition) -> CGPoint {
        let r = selectionRect
        switch position {
        case .topLeft:      return CGPoint(x: r.minX, y: r.maxY)
        case .topCenter:    return CGPoint(x: r.midX, y: r.maxY)
        case .topRight:     return CGPoint(x: r.maxX, y: r.maxY)
        case .middleLeft:   return CGPoint(x: r.minX, y: r.midY)
        case .middleRight:  return CGPoint(x: r.maxX, y: r.midY)
        case .bottomLeft:   return CGPoint(x: r.minX, y: r.minY)
        case .bottomCenter: return CGPoint(x: r.midX, y: r.minY)
        case .bottomRight:  return CGPoint(x: r.maxX, y: r.minY)
        }
    }
    
    /// Returns the handle hit at a point, or nil.
    func hitHandle(at point: NSPoint) -> HandlePosition? {
        let hitRadius: CGFloat = handleRadius + 4.0
        for position in HandlePosition.allCases {
            let hp = handlePoint(for: position)
            let dx = point.x - hp.x
            let dy = point.y - hp.y
            if dx * dx + dy * dy <= hitRadius * hitRadius {
                return position
            }
        }
        return nil
    }
    
    /// Returns a normalized rect (positive width/height) from any two points.
    static func normalizedRect(from p1: CGPoint, to p2: CGPoint) -> CGRect {
        let x = min(p1.x, p2.x)
        let y = min(p1.y, p2.y)
        let w = abs(p2.x - p1.x)
        let h = abs(p2.y - p1.y)
        return CGRect(x: x, y: y, width: w, height: h)
    }
    
    /// Compute the new rect when resizing from a handle.
    static func resizedRect(original: CGRect, handle: HandlePosition, delta: CGPoint, minimumSize: CGFloat) -> CGRect {
        var minX = original.minX
        var minY = original.minY
        var maxX = original.maxX
        var maxY = original.maxY
        
        switch handle {
        case .topLeft:
            minX += delta.x
            maxY += delta.y
        case .topCenter:
            maxY += delta.y
        case .topRight:
            maxX += delta.x
            maxY += delta.y
        case .middleLeft:
            minX += delta.x
        case .middleRight:
            maxX += delta.x
        case .bottomLeft:
            minX += delta.x
            minY += delta.y
        case .bottomCenter:
            minY += delta.y
        case .bottomRight:
            maxX += delta.x
            minY += delta.y
        }
        
        // Enforce minimum size
        if maxX - minX < minimumSize {
            if handle == .topLeft || handle == .middleLeft || handle == .bottomLeft {
                minX = maxX - minimumSize
            } else {
                maxX = minX + minimumSize
            }
        }
        if maxY - minY < minimumSize {
            if handle == .bottomLeft || handle == .bottomCenter || handle == .bottomRight {
                minY = maxY - minimumSize
            } else {
                maxY = minY + minimumSize
            }
        }
        
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
    // MARK: - Mouse Events
    
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        
        if hasSelection {
            // Check handle hit
            if let handle = hitHandle(at: point) {
                state = .resizing(handle: handle, startPoint: point, originalRect: selectionRect)
                return
            }
            // Check if inside selection for moving
            if selectionRect.contains(point) {
                state = .moving(startPoint: point, originalRect: selectionRect)
                return
            }
        }
        
        // Start new selection
        state = .drawing(startPoint: point)
        selectionRect = .zero
        setNeedsDisplay(bounds)
    }
    
    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        
        switch state {
        case .drawing(let startPoint):
            selectionRect = SelectionOverlayView.normalizedRect(from: startPoint, to: point)
            
        case .moving(let startPoint, let originalRect):
            let dx = point.x - startPoint.x
            let dy = point.y - startPoint.y
            var newRect = originalRect.offsetBy(dx: dx, dy: dy)
            // Clamp to view bounds
            newRect.origin.x = max(0, min(newRect.origin.x, bounds.width - newRect.width))
            newRect.origin.y = max(0, min(newRect.origin.y, bounds.height - newRect.height))
            selectionRect = newRect
            
        case .resizing(let handle, let startPoint, let originalRect):
            let delta = CGPoint(x: point.x - startPoint.x, y: point.y - startPoint.y)
            selectionRect = SelectionOverlayView.resizedRect(
                original: originalRect,
                handle: handle,
                delta: delta,
                minimumSize: minimumSelectionSize
            )
            
        case .idle:
            break
        }
        
        setNeedsDisplay(bounds)
    }
    
    override func mouseUp(with event: NSEvent) {
        switch state {
        case .drawing:
            if selectionRect.width >= minimumSelectionSize && selectionRect.height >= minimumSelectionSize {
                onSelectionComplete?(selectionRect)
            }
        case .moving, .resizing:
            onSelectionComplete?(selectionRect)
        case .idle:
            break
        }
        state = .idle
    }
    
    // MARK: - Keyboard Events
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC
            onCancelled?()
        }
    }
    
    // MARK: - Cursor
    
    override func resetCursorRects() {
        if hasSelection {
            // Handles cursors
            for position in HandlePosition.allCases {
                let hp = handlePoint(for: position)
                let cursorRect = CGRect(x: hp.x - 5, y: hp.y - 5, width: 10, height: 10)
                let cursor: NSCursor
                switch position {
                case .topLeft, .bottomRight:
                    cursor = .crosshair
                case .topRight, .bottomLeft:
                    cursor = .crosshair
                case .topCenter, .bottomCenter:
                    cursor = .resizeUpDown
                case .middleLeft, .middleRight:
                    cursor = .resizeLeftRight
                }
                addCursorRect(cursorRect, cursor: cursor)
            }
            // Move cursor inside selection
            addCursorRect(selectionRect, cursor: .openHand)
        } else {
            addCursorRect(bounds, cursor: .crosshair)
        }
    }
    
    // MARK: - Public Helpers
    
    /// Convert the selection rect from view coordinates to screen coordinates.
    func selectionRectInScreenCoordinates() -> CGRect? {
        guard hasSelection, let window = self.window, let screen = window.screen else { return nil }
        let windowRect = convert(selectionRect, to: nil)
        let screenRect = window.convertToScreen(windowRect)
        // Flip Y for CGWindowListCreateImage (uses top-left origin)
        let flippedY = screen.frame.height - screenRect.maxY + screen.frame.origin.y
        return CGRect(x: screenRect.origin.x, y: flippedY, width: screenRect.width, height: screenRect.height)
    }
}

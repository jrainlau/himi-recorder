import CoreGraphics
import CoreMedia

/// Protocol abstracting screen capture capability for testability.
/// Production uses CGWindowListCreateImage; tests inject MockScreenCapturer.
protocol ScreenCapturing: AnyObject {
    /// The screen rect to capture (in global display coordinates).
    var captureRect: CGRect { get set }
    
    /// Capture frame rate (24, 30, or 60 fps).
    var frameRate: Int { get set }
    
    /// Whether the engine is currently capturing frames.
    var isCapturing: Bool { get }
    
    /// Called for each captured frame with the CGImage and presentation time.
    var onFrameCaptured: ((CGImage, CMTime) -> Void)? { get set }
    
    /// Called when a capture error occurs.
    var onError: ((Error) -> Void)? { get set }
    
    /// Start capturing frames at the configured frame rate.
    func startCapture()
    
    /// Stop capturing frames.
    func stopCapture()
}

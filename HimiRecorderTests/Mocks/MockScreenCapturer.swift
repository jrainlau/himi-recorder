import Foundation
import CoreGraphics
import CoreMedia
@testable import HimiRecorder

/// Mock screen capturer that returns pre-set test images.
final class MockScreenCapturer: ScreenCapturing {
    var captureRect: CGRect = .zero
    var frameRate: Int = 60
    private(set) var isCapturing: Bool = false
    var onFrameCaptured: ((CGImage, CMTime) -> Void)?
    var onError: ((Error) -> Void)?
    
    var startCaptureCallCount = 0
    var stopCaptureCallCount = 0
    
    /// Test image to return for each frame.
    var testImage: CGImage?
    
    func startCapture() {
        startCaptureCallCount += 1
        isCapturing = true
    }
    
    func stopCapture() {
        stopCaptureCallCount += 1
        isCapturing = false
    }
    
    /// Simulate a captured frame for testing.
    func simulateFrame(at time: CMTime) {
        guard let image = testImage ?? TestHelper.createTestImage() else { return }
        onFrameCaptured?(image, time)
    }
}

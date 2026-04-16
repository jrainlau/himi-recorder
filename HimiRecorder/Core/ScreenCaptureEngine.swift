import Foundation
import CoreGraphics
import CoreMedia
import CoreVideo
import Cocoa
import ScreenCaptureKit

/// Screen capture engine using ScreenCaptureKit SCStream.
/// Captures frames via the stream output delegate for reliable, high-performance recording.
final class ScreenCaptureEngine: NSObject, ScreenCapturing, SCStreamOutput {
    
    var captureRect: CGRect = .zero  // In CG coordinates (top-left origin)
    var frameRate: Int = 60
    private(set) var isCapturing: Bool = false
    
    var onFrameCaptured: ((CGImage, CMTime) -> Void)?
    var onError: ((Error) -> Void)?
    /// Called on main thread when the stream has started and frames are flowing.
    var onCaptureStarted: (() -> Void)?
    
    private var stream: SCStream?
    private var contentFilter: SCContentFilter?
    private var targetDisplay: SCDisplay?
    private var frameCount: Int64 = 0
    private var hasNotifiedStart = false
    
    func startCapture() {
        guard !isCapturing else { return }
        guard captureRect.width > 0 && captureRect.height > 0 else {
            onError?(CaptureError.invalidRect)
            return
        }
        
        isCapturing = true
        frameCount = 0
        hasNotifiedStart = false
        
        Task {
            do {
                try await setupAndStartStream()
            } catch {
                print("[ScreenCaptureEngine] Failed to start: \(error)")
                await MainActor.run {
                    self.isCapturing = false
                    self.onError?(CaptureError.setupFailed(error))
                }
            }
        }
    }
    
    private func setupAndStartStream() async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        
        // Find the display that contains our capture rect
        guard let display = content.displays.first(where: { display in
            let bounds = CGRect(x: CGFloat(display.frame.origin.x),
                                y: CGFloat(display.frame.origin.y),
                                width: CGFloat(display.width),
                                height: CGFloat(display.height))
            return bounds.intersects(self.captureRect)
        }) ?? content.displays.first else {
            throw CaptureError.noDisplay
        }
        
        self.targetDisplay = display
        
        // Exclude our own app's windows
        let appBundleID = Bundle.main.bundleIdentifier ?? "com.himi.recorder"
        let excludedApps = content.applications.filter { $0.bundleIdentifier == appBundleID }
        
        let filter = SCContentFilter(display: display, excludingApplications: excludedApps, exceptingWindows: [])
        self.contentFilter = filter
        
        // Configure the stream
        let config = SCStreamConfiguration()
        // Capture at Retina resolution
        config.width = display.width * 2
        config.height = display.height * 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(frameRate))
        config.showsCursor = true
        config.capturesAudio = false
        config.queueDepth = 5
        
        // Set the source rect to capture only our region of interest
        // SCStream sourceRect is in display points (CG coordinates relative to the display)
        let displayOriginX = CGFloat(display.frame.origin.x)
        let displayOriginY = CGFloat(display.frame.origin.y)
        
        config.sourceRect = CGRect(
            x: captureRect.origin.x - displayOriginX,
            y: captureRect.origin.y - displayOriginY,
            width: captureRect.width,
            height: captureRect.height
        )
        
        // Output dimensions match capture area in pixels (Retina 2x)
        config.width = Int(captureRect.width) * 2
        config.height = Int(captureRect.height) * 2
        
        let displayBounds = CGRect(x: displayOriginX, y: displayOriginY,
                                    width: CGFloat(display.width), height: CGFloat(display.height))
        print("[ScreenCaptureEngine] Display: \(displayBounds)")
        print("[ScreenCaptureEngine] CaptureRect: \(captureRect)")
        print("[ScreenCaptureEngine] SourceRect: \(config.sourceRect)")
        print("[ScreenCaptureEngine] Output: \(config.width)x\(config.height) @ \(frameRate)fps")
        
        // Create and start the stream
        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: DispatchQueue(label: "com.himi.recorder.stream", qos: .userInteractive))
        
        try await stream.startCapture()
        self.stream = stream
        
        print("[ScreenCaptureEngine] Stream started successfully")
    }
    
    func stopCapture() {
        guard isCapturing else { return }
        isCapturing = false
        
        if let stream = stream {
            Task {
                do {
                    try await stream.stopCapture()
                } catch {
                    print("[ScreenCaptureEngine] Error stopping stream: \(error)")
                }
            }
        }
        stream = nil
    }
    
    // MARK: - SCStreamOutput
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard isCapturing, type == .screen else { return }
        
        // Notify that capture has started (first frame received)
        if !hasNotifiedStart {
            hasNotifiedStart = true
            DispatchQueue.main.async {
                self.onCaptureStarted?()
            }
        }
        
        guard let imageBuffer = sampleBuffer.imageBuffer else { return }
        
        // Convert CVPixelBuffer to CGImage
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext()
        let rect = CGRect(x: 0, y: 0, width: CVPixelBufferGetWidth(imageBuffer), height: CVPixelBufferGetHeight(imageBuffer))
        
        guard let cgImage = context.createCGImage(ciImage, from: rect) else { return }
        
        let time = CMTime(value: frameCount, timescale: CMTimeScale(frameRate))
        frameCount += 1
        
        onFrameCaptured?(cgImage, time)
    }
    
    enum CaptureError: Error, LocalizedError {
        case invalidRect
        case captureImageFailed
        case noDisplay
        case setupFailed(Error)
        
        var errorDescription: String? {
            switch self {
            case .invalidRect: return "Invalid capture rectangle"
            case .captureImageFailed: return "Failed to capture screen image"
            case .noDisplay: return "No display found for capture area"
            case .setupFailed(let e): return "Setup failed: \(e.localizedDescription)"
            }
        }
    }
}

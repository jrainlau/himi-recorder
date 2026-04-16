import Foundation
import CoreGraphics
import CoreMedia

/// Provides test utilities for creating test images, temporary directories, etc.
enum TestHelper {
    
    /// Create a test CGImage with the specified dimensions and solid color.
    static func createTestImage(width: Int = 100, height: Int = 100, red: CGFloat = 1.0, green: CGFloat = 0.0, blue: CGFloat = 0.0) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        
        context.setFillColor(CGColor(red: red, green: green, blue: blue, alpha: 1.0))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        
        return context.makeImage()
    }
    
    /// Create a temporary directory for test output.
    static func createTempDirectory() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("HimiRecorderTests_\(UUID().uuidString)")
        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        } catch {
            fatalError("Failed to create temp directory: \(error)")
        }
        return tempDir
    }
    
    /// Remove a temporary directory.
    static func removeTempDirectory(_ url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            print("Warning: Failed to remove temp directory: \(error)")
        }
    }
    
    /// Create a CMTime for a given frame number and frame rate.
    static func time(forFrame frame: Int, frameRate: Int) -> CMTime {
        return CMTime(value: CMTimeValue(frame), timescale: CMTimeScale(frameRate))
    }
}

import CoreGraphics
import CoreVideo

/// Extension to convert CGImage to CVPixelBuffer for video encoding.
extension CGImage {
    
    /// Convert this CGImage to a CVPixelBuffer.
    /// - Parameters:
    ///   - pool: Optional pixel buffer pool for memory reuse.
    ///   - width: Target width (defaults to image width).
    ///   - height: Target height (defaults to image height).
    /// - Returns: A CVPixelBuffer containing the image data, or nil on failure.
    func toPixelBuffer(pool: CVPixelBufferPool? = nil, width: Int? = nil, height: Int? = nil) -> CVPixelBuffer? {
        let targetWidth = width ?? self.width
        let targetHeight = height ?? self.height
        
        var pixelBuffer: CVPixelBuffer?
        
        if let pool = pool {
            let status = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)
            if status != kCVReturnSuccess {
                print("[CGImage+PixelBuffer] Failed to create pixel buffer from pool: \(status)")
                return nil
            }
        } else {
            let attrs: [String: Any] = [
                kCVPixelBufferCGImageCompatibilityKey as String: true,
                kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
                kCVPixelBufferIOSurfacePropertiesKey as String: [:]
            ]
            let status = CVPixelBufferCreate(
                nil,
                targetWidth,
                targetHeight,
                kCVPixelFormatType_32BGRA,
                attrs as CFDictionary,
                &pixelBuffer
            )
            if status != kCVReturnSuccess {
                print("[CGImage+PixelBuffer] Failed to create pixel buffer: \(status)")
                return nil
            }
        }
        
        guard let buffer = pixelBuffer else { return nil }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else { return nil }
        
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let context = CGContext(
            data: baseAddress,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return nil }
        
        context.draw(self, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        
        return buffer
    }
    
    /// Create a CVPixelBufferPool suitable for the given dimensions.
    static func createPixelBufferPool(width: Int, height: Int) -> CVPixelBufferPool? {
        let poolAttributes: [String: Any] = [
            kCVPixelBufferPoolMinimumBufferCountKey as String: 3
        ]
        
        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]
        
        var pool: CVPixelBufferPool?
        let status = CVPixelBufferPoolCreate(
            nil,
            poolAttributes as CFDictionary,
            pixelBufferAttributes as CFDictionary,
            &pool
        )
        
        if status != kCVReturnSuccess {
            print("[CGImage+PixelBuffer] Failed to create pixel buffer pool: \(status)")
            return nil
        }
        
        return pool
    }
}

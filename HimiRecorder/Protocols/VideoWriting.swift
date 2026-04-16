import CoreGraphics
import CoreMedia
import Foundation

/// Protocol abstracting video writing capability for testability.
/// Production uses AVAssetWriter; tests inject MockVideoWriter.
protocol VideoWriting: AnyObject {
    /// Start writing video to the specified URL.
    /// - Parameters:
    ///   - url: Output file URL (.mp4)
    ///   - width: Video width in pixels
    ///   - height: Video height in pixels
    ///   - frameRate: Target frame rate
    func startWriting(to url: URL, width: Int, height: Int, frameRate: Int) throws
    
    /// Append a single frame to the video.
    /// - Parameters:
    ///   - image: The frame image
    ///   - time: Presentation timestamp
    func appendFrame(_ image: CGImage, at time: CMTime) throws
    
    /// Finish writing and finalize the MP4 file.
    /// - Parameter completion: Called with the output URL on success or an error.
    func finishWriting(completion: @escaping (Result<URL, Error>) -> Void)
    
    /// Whether the writer is currently active.
    var isWriting: Bool { get }
}

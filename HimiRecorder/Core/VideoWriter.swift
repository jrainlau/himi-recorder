import Foundation
import AVFoundation
import CoreMedia
import CoreGraphics
import CoreVideo

/// Encodes CGImage frames into H.264 MP4 video using AVAssetWriter.
final class VideoWriter: VideoWriting {
    
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var pixelBufferPool: CVPixelBufferPool?
    private var outputURL: URL?
    private var videoWidth: Int = 0
    private var videoHeight: Int = 0
    
    private(set) var isWriting: Bool = false
    private let writerQueue = DispatchQueue(label: "com.himi.recorder.writer")
    
    func startWriting(to url: URL, width: Int, height: Int, frameRate: Int) throws {
        // Remove existing file
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        
        self.outputURL = url
        self.videoWidth = width
        self.videoHeight = height
        
        let writer = try AVAssetWriter(url: url, fileType: .mp4)
        
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: width * height * 4,
                AVVideoExpectedSourceFrameRateKey: frameRate,
                AVVideoMaxKeyFrameIntervalKey: frameRate * 2,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]
        
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        input.expectsMediaDataInRealTime = true
        
        let sourcePixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]
        
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: sourcePixelBufferAttributes
        )
        
        guard writer.canAdd(input) else {
            throw WriterError.cannotAddInput
        }
        
        writer.add(input)
        
        guard writer.startWriting() else {
            throw WriterError.failedToStart(writer.error)
        }
        
        writer.startSession(atSourceTime: .zero)
        
        self.assetWriter = writer
        self.videoInput = input
        self.pixelBufferAdaptor = adaptor
        self.pixelBufferPool = adaptor.pixelBufferPool ?? CGImage.createPixelBufferPool(width: width, height: height)
        self.isWriting = true
    }
    
    func appendFrame(_ image: CGImage, at time: CMTime) throws {
        guard isWriting, let input = videoInput, let adaptor = pixelBufferAdaptor else {
            throw WriterError.notWriting
        }
        
        guard input.isReadyForMoreMediaData else {
            // Skip frame if writer is not ready
            return
        }
        
        guard let pixelBuffer = image.toPixelBuffer(pool: pixelBufferPool, width: videoWidth, height: videoHeight) else {
            throw WriterError.pixelBufferConversionFailed
        }
        
        if !adaptor.append(pixelBuffer, withPresentationTime: time) {
            throw WriterError.appendFailed(assetWriter?.error)
        }
    }
    
    func finishWriting(completion: @escaping (Result<URL, Error>) -> Void) {
        guard isWriting, let writer = assetWriter, let url = outputURL else {
            completion(.failure(WriterError.notWriting))
            return
        }
        
        isWriting = false
        videoInput?.markAsFinished()
        
        writer.finishWriting { [weak self] in
            self?.cleanup()
            
            if writer.status == .completed {
                completion(.success(url))
            } else {
                completion(.failure(writer.error ?? WriterError.unknownError))
            }
        }
    }
    
    private func cleanup() {
        assetWriter = nil
        videoInput = nil
        pixelBufferAdaptor = nil
        pixelBufferPool = nil
    }
    
    enum WriterError: Error, LocalizedError {
        case cannotAddInput
        case failedToStart(Error?)
        case notWriting
        case pixelBufferConversionFailed
        case appendFailed(Error?)
        case unknownError
        
        var errorDescription: String? {
            switch self {
            case .cannotAddInput: return "Cannot add video input to asset writer"
            case .failedToStart(let e): return "Failed to start writing: \(e?.localizedDescription ?? "unknown")"
            case .notWriting: return "Video writer is not in writing state"
            case .pixelBufferConversionFailed: return "Failed to convert CGImage to CVPixelBuffer"
            case .appendFailed(let e): return "Failed to append frame: \(e?.localizedDescription ?? "unknown")"
            case .unknownError: return "Unknown video writer error"
            }
        }
    }
}

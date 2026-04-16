import Foundation
import CoreGraphics
import CoreMedia
@testable import HimiRecorder

/// Mock video writer that records calls instead of actually encoding.
final class MockVideoWriter: VideoWriting {
    private(set) var isWriting: Bool = false
    
    var startWritingCallCount = 0
    var appendFrameCallCount = 0
    var finishWritingCallCount = 0
    var appendedTimes: [CMTime] = []
    var lastOutputURL: URL?
    var lastWidth: Int = 0
    var lastHeight: Int = 0
    var lastFrameRate: Int = 0
    
    var shouldFailOnStart = false
    var shouldFailOnAppend = false
    
    func startWriting(to url: URL, width: Int, height: Int, frameRate: Int) throws {
        if shouldFailOnStart {
            throw MockError.startFailed
        }
        startWritingCallCount += 1
        lastOutputURL = url
        lastWidth = width
        lastHeight = height
        lastFrameRate = frameRate
        isWriting = true
    }
    
    func appendFrame(_ image: CGImage, at time: CMTime) throws {
        if shouldFailOnAppend {
            throw MockError.appendFailed
        }
        appendFrameCallCount += 1
        appendedTimes.append(time)
    }
    
    func finishWriting(completion: @escaping (Result<URL, Error>) -> Void) {
        finishWritingCallCount += 1
        isWriting = false
        if let url = lastOutputURL {
            completion(.success(url))
        } else {
            completion(.failure(MockError.noURL))
        }
    }
    
    enum MockError: Error {
        case startFailed
        case appendFailed
        case noURL
    }
}

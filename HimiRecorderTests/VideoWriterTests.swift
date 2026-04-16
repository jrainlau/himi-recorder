import XCTest
import CoreMedia
import AVFoundation
@testable import HimiRecorder

final class VideoWriterTests: XCTestCase {
    
    private var tempDir: URL!
    
    override func setUp() {
        super.setUp()
        tempDir = TestHelper.createTempDirectory()
    }
    
    override func tearDown() {
        if let dir = tempDir {
            TestHelper.removeTempDirectory(dir)
        }
        super.tearDown()
    }
    
    // MARK: - MockVideoWriter Tests
    
    func testMockVideoWriterInitialState() {
        let mock = MockVideoWriter()
        XCTAssertFalse(mock.isWriting)
        XCTAssertEqual(mock.startWritingCallCount, 0)
    }
    
    func testMockVideoWriterStartWriting() throws {
        let mock = MockVideoWriter()
        let url = tempDir.appendingPathComponent("test.mp4")
        
        try mock.startWriting(to: url, width: 100, height: 100, frameRate: 30)
        
        XCTAssertTrue(mock.isWriting)
        XCTAssertEqual(mock.startWritingCallCount, 1)
        XCTAssertEqual(mock.lastWidth, 100)
        XCTAssertEqual(mock.lastHeight, 100)
        XCTAssertEqual(mock.lastFrameRate, 30)
    }
    
    func testMockVideoWriterAppendFrame() throws {
        let mock = MockVideoWriter()
        let url = tempDir.appendingPathComponent("test.mp4")
        try mock.startWriting(to: url, width: 100, height: 100, frameRate: 30)
        
        guard let image = TestHelper.createTestImage() else {
            XCTFail("Failed to create test image")
            return
        }
        
        try mock.appendFrame(image, at: CMTime(value: 0, timescale: 30))
        try mock.appendFrame(image, at: CMTime(value: 1, timescale: 30))
        
        XCTAssertEqual(mock.appendFrameCallCount, 2)
        XCTAssertEqual(mock.appendedTimes.count, 2)
    }
    
    func testMockVideoWriterFinish() throws {
        let mock = MockVideoWriter()
        let url = tempDir.appendingPathComponent("test.mp4")
        try mock.startWriting(to: url, width: 100, height: 100, frameRate: 30)
        
        let expectation = XCTestExpectation(description: "Finish writing")
        mock.finishWriting { result in
            switch result {
            case .success(let outputURL):
                XCTAssertEqual(outputURL, url)
            case .failure:
                XCTFail("Should succeed")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertFalse(mock.isWriting)
    }
    
    func testMockVideoWriterFailOnStart() {
        let mock = MockVideoWriter()
        mock.shouldFailOnStart = true
        let url = tempDir.appendingPathComponent("test.mp4")
        
        XCTAssertThrowsError(try mock.startWriting(to: url, width: 100, height: 100, frameRate: 30))
    }
    
    // MARK: - Real VideoWriter Tests
    
    func testRealVideoWriterInitialState() {
        let writer = VideoWriter()
        XCTAssertFalse(writer.isWriting)
    }
    
    func testRealVideoWriterCreateMP4() throws {
        let writer = VideoWriter()
        let url = tempDir.appendingPathComponent("output.mp4")
        
        try writer.startWriting(to: url, width: 100, height: 100, frameRate: 30)
        XCTAssertTrue(writer.isWriting)
        
        guard let image = TestHelper.createTestImage(width: 100, height: 100) else {
            XCTFail("Failed to create test image")
            return
        }
        
        // Write 10 frames
        for i in 0..<10 {
            try writer.appendFrame(image, at: CMTime(value: CMTimeValue(i), timescale: 30))
            // Small delay to allow writer to process
            Thread.sleep(forTimeInterval: 0.01)
        }
        
        let expectation = XCTestExpectation(description: "Finish writing")
        writer.finishWriting { result in
            switch result {
            case .success(let outputURL):
                // Verify file exists and is a valid MP4
                XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
                let fileSize = (try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? UInt64) ?? 0
                XCTAssertGreaterThan(fileSize, 0, "Output MP4 should have non-zero size")
            case .failure(let error):
                XCTFail("VideoWriter failed: \(error)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testRealVideoWriterOutputIsValidMP4() throws {
        let writer = VideoWriter()
        let url = tempDir.appendingPathComponent("valid.mp4")
        
        try writer.startWriting(to: url, width: 200, height: 150, frameRate: 24)
        
        guard let image = TestHelper.createTestImage(width: 200, height: 150) else {
            XCTFail("Failed to create test image")
            return
        }
        
        for i in 0..<24 {
            try writer.appendFrame(image, at: CMTime(value: CMTimeValue(i), timescale: 24))
            Thread.sleep(forTimeInterval: 0.01)
        }
        
        let expectation = XCTestExpectation(description: "Verify MP4")
        writer.finishWriting { result in
            switch result {
            case .success(let outputURL):
                // Use AVAsset to verify the MP4 is valid
                let asset = AVAsset(url: outputURL)
                let tracks = asset.tracks(withMediaType: .video)
                XCTAssertEqual(tracks.count, 1, "Should have exactly one video track")
                
                if let track = tracks.first {
                    XCTAssertEqual(Int(track.naturalSize.width), 200)
                    XCTAssertEqual(Int(track.naturalSize.height), 150)
                }
                
            case .failure(let error):
                XCTFail("VideoWriter failed: \(error)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testAppendFrameWithoutStartThrows() {
        let writer = VideoWriter()
        guard let image = TestHelper.createTestImage() else {
            XCTFail("Failed to create test image")
            return
        }
        
        XCTAssertThrowsError(try writer.appendFrame(image, at: .zero))
    }
    
    // MARK: - Protocol Conformance
    
    func testProtocolConformance() throws {
        let writer: VideoWriting = VideoWriter()
        XCTAssertFalse(writer.isWriting)
        
        let mockWriter: VideoWriting = MockVideoWriter()
        XCTAssertFalse(mockWriter.isWriting)
    }
}

import XCTest
import CoreMedia
@testable import HimiRecorder

final class ScreenCaptureEngineTests: XCTestCase {
    
    // MARK: - MockScreenCapturer Tests
    
    func testMockScreenCapturerInitialState() {
        let mock = MockScreenCapturer()
        XCTAssertFalse(mock.isCapturing)
        XCTAssertEqual(mock.startCaptureCallCount, 0)
        XCTAssertEqual(mock.stopCaptureCallCount, 0)
    }
    
    func testMockScreenCapturerStartStop() {
        let mock = MockScreenCapturer()
        mock.startCapture()
        XCTAssertTrue(mock.isCapturing)
        XCTAssertEqual(mock.startCaptureCallCount, 1)
        
        mock.stopCapture()
        XCTAssertFalse(mock.isCapturing)
        XCTAssertEqual(mock.stopCaptureCallCount, 1)
    }
    
    func testMockScreenCapturerFrameCallback() {
        let mock = MockScreenCapturer()
        var receivedFrame = false
        
        mock.onFrameCaptured = { image, time in
            receivedFrame = true
            XCTAssertGreaterThan(image.width, 0)
        }
        
        mock.simulateFrame(at: CMTime(value: 0, timescale: 60))
        XCTAssertTrue(receivedFrame)
    }
    
    // MARK: - Real ScreenCaptureEngine Tests
    
    func testRealEngineInitialState() {
        let engine = ScreenCaptureEngine()
        XCTAssertFalse(engine.isCapturing)
        XCTAssertEqual(engine.frameRate, 60)
        XCTAssertEqual(engine.captureRect, .zero)
    }
    
    func testRealEngineRejectsZeroRect() {
        let engine = ScreenCaptureEngine()
        engine.captureRect = .zero
        
        var errorReceived = false
        engine.onError = { _ in errorReceived = true }
        
        engine.startCapture()
        XCTAssertFalse(engine.isCapturing)
        XCTAssertTrue(errorReceived)
    }
    
    func testRealEngineStartStop() {
        let engine = ScreenCaptureEngine()
        engine.captureRect = CGRect(x: 0, y: 0, width: 100, height: 100)
        engine.frameRate = 30
        
        engine.startCapture()
        XCTAssertTrue(engine.isCapturing)
        
        engine.stopCapture()
        XCTAssertFalse(engine.isCapturing)
    }
    
    func testRealEngineDoesNotDoubleStart() {
        let engine = ScreenCaptureEngine()
        engine.captureRect = CGRect(x: 0, y: 0, width: 100, height: 100)
        
        engine.startCapture()
        engine.startCapture() // Should be no-op
        XCTAssertTrue(engine.isCapturing)
        
        engine.stopCapture()
    }
    
    func testRealEngineStopWhenNotCapturing() {
        let engine = ScreenCaptureEngine()
        // Should not crash
        engine.stopCapture()
        XCTAssertFalse(engine.isCapturing)
    }
    
    func testRealEngineCapturesFrames() {
        let engine = ScreenCaptureEngine()
        engine.captureRect = CGRect(x: 0, y: 0, width: 100, height: 100)
        engine.frameRate = 30
        
        let completionExpectation = XCTestExpectation(description: "Capture attempt completed")
        var framesCaptured = 0
        var setupFailed = false
        
        engine.onCaptureStarted = {
            // Setup succeeded
        }
        
        engine.onError = { error in
            // ScreenCaptureKit may fail in test environment (no permission)
            setupFailed = true
            completionExpectation.fulfill()
        }
        
        engine.onFrameCaptured = { image, time in
            framesCaptured += 1
            if framesCaptured >= 3 {
                completionExpectation.fulfill()
            }
        }
        
        engine.startCapture()
        wait(for: [completionExpectation], timeout: 8.0)
        engine.stopCapture()
        
        if !setupFailed {
            XCTAssertGreaterThanOrEqual(framesCaptured, 3)
        }
        // If setupFailed, test passes gracefully (no SCK permission in test env)
    }
    
    func testFrameRateSettable() {
        let engine = ScreenCaptureEngine()
        engine.frameRate = 24
        XCTAssertEqual(engine.frameRate, 24)
        engine.frameRate = 30
        XCTAssertEqual(engine.frameRate, 30)
        engine.frameRate = 60
        XCTAssertEqual(engine.frameRate, 60)
    }
    
    // MARK: - Protocol Conformance
    
    func testProtocolConformanceMock() {
        let capturer: ScreenCapturing = MockScreenCapturer()
        capturer.captureRect = CGRect(x: 0, y: 0, width: 200, height: 200)
        capturer.frameRate = 30
        capturer.startCapture()
        XCTAssertTrue(capturer.isCapturing)
        capturer.stopCapture()
        XCTAssertFalse(capturer.isCapturing)
    }
    
    func testProtocolConformanceReal() {
        let capturer: ScreenCapturing = ScreenCaptureEngine()
        capturer.captureRect = CGRect(x: 0, y: 0, width: 200, height: 200)
        capturer.frameRate = 60
        XCTAssertEqual(capturer.frameRate, 60)
    }
}

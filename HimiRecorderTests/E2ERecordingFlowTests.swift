import XCTest
import CoreMedia
@testable import HimiRecorder

/// End-to-end integration tests that verify the complete recording flow
/// using mock objects to avoid requiring actual screen capture permissions.
final class E2ERecordingFlowTests: XCTestCase {
    
    // MARK: - Full Pipeline: Mock Capture -> Real VideoWriter -> MP4
    
    func testFullPipelineMockCaptureToRealMP4() throws {
        let tempDir = TestHelper.createTempDirectory()
        defer { TestHelper.removeTempDirectory(tempDir) }
        
        let outputURL = tempDir.appendingPathComponent("e2e_test.mp4")
        
        // 1. Create mock screen capturer
        let capturer = MockScreenCapturer()
        capturer.captureRect = CGRect(x: 0, y: 0, width: 200, height: 150)
        capturer.frameRate = 30
        capturer.testImage = TestHelper.createTestImage(width: 200, height: 150)
        
        // 2. Create real video writer
        let writer = VideoWriter()
        try writer.startWriting(to: outputURL, width: 200, height: 150, frameRate: 30)
        
        // 3. Connect capturer to writer
        capturer.onFrameCaptured = { image, time in
            do {
                try writer.appendFrame(image, at: time)
            } catch {
                XCTFail("Failed to append frame: \(error)")
            }
        }
        
        // 4. Simulate 30 frames (1 second)
        capturer.startCapture()
        for i in 0..<30 {
            capturer.simulateFrame(at: CMTime(value: CMTimeValue(i), timescale: 30))
            Thread.sleep(forTimeInterval: 0.01)
        }
        capturer.stopCapture()
        
        // 5. Finish writing
        let expectation = XCTestExpectation(description: "E2E finish writing")
        writer.finishWriting { result in
            switch result {
            case .success(let url):
                XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
                let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? UInt64) ?? 0
                XCTAssertGreaterThan(fileSize, 0)
            case .failure(let error):
                XCTFail("E2E pipeline failed: \(error)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Full Pipeline with 60fps
    
    func testFullPipeline60fps() throws {
        let tempDir = TestHelper.createTempDirectory()
        defer { TestHelper.removeTempDirectory(tempDir) }
        
        let outputURL = tempDir.appendingPathComponent("e2e_60fps.mp4")
        let writer = VideoWriter()
        try writer.startWriting(to: outputURL, width: 320, height: 240, frameRate: 60)
        
        let capturer = MockScreenCapturer()
        capturer.testImage = TestHelper.createTestImage(width: 320, height: 240)
        
        capturer.onFrameCaptured = { image, time in
            do { try writer.appendFrame(image, at: time) } catch { XCTFail("\(error)") }
        }
        
        for i in 0..<60 {
            capturer.simulateFrame(at: CMTime(value: CMTimeValue(i), timescale: 60))
            Thread.sleep(forTimeInterval: 0.005)
        }
        
        let expectation = XCTestExpectation(description: "60fps E2E")
        writer.finishWriting { result in
            if case .failure(let error) = result { XCTFail("\(error)") }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Settings Integration
    
    func testSettingsIntegrationWithMockCapture() {
        let settings = MockSettingsStore()
        settings.frameRate = 24
        
        let capturer = MockScreenCapturer()
        capturer.frameRate = settings.frameRate
        
        XCTAssertEqual(capturer.frameRate, 24)
        
        settings.frameRate = 60
        capturer.frameRate = settings.frameRate
        XCTAssertEqual(capturer.frameRate, 60)
    }
    
    // MARK: - Hotkey Integration with Mock
    
    func testHotkeyTriggersRecordingStart() {
        let mock = MockHotKeyRegistrar()
        let combo = KeyCombo(keyCode: 15, modifiers: NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue)
        
        var recordingStarted = false
        _ = mock.register(shortcut: combo) {
            recordingStarted = true
        }
        
        mock.simulateTrigger(index: 0)
        XCTAssertTrue(recordingStarted)
    }
    
    func testHotkeyTriggersRecordingStop() {
        let mock = MockHotKeyRegistrar()
        let startCombo = KeyCombo(keyCode: 15, modifiers: NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue)
        let stopCombo = KeyCombo(keyCode: 1, modifiers: NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue)
        
        var started = false
        var stopped = false
        
        _ = mock.register(shortcut: startCombo) { started = true }
        _ = mock.register(shortcut: stopCombo) { stopped = true }
        
        mock.simulateTrigger(index: 0)
        XCTAssertTrue(started)
        
        mock.simulateTrigger(index: 1)
        XCTAssertTrue(stopped)
    }
    
    // MARK: - Selection Geometry + Control Bar Integration
    
    func testSelectionToControlBarFlow() {
        // Use NS screen coordinates (bottom-left origin)
        let selectionNSRect = CGRect(x: 100, y: 200, width: 500, height: 300)
        
        let controlBar = ControlBarWindow()
        controlBar.updateSizeLabel(width: Int(selectionNSRect.width), height: Int(selectionNSRect.height))
        controlBar.positionBelow(selectionNSRect: selectionNSRect)
        
        // Verify horizontal centering
        XCTAssertEqual(controlBar.frame.midX, selectionNSRect.midX, accuracy: 1.0)
        // Verify below selection
        XCTAssertLessThan(controlBar.frame.maxY, selectionNSRect.minY)
    }
    
    // MARK: - Real Screen Capture Produces Valid Image
    
    func testRealCGWindowListCreateImageProducesImage() {
        // Test that CGWindowListCreateImage with .optionOnScreenOnly actually works
        // Using a known-good small rect at the top-left corner of main screen
        let cgRect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let image = CGWindowListCreateImage(
            cgRect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution]
        )
        
        // This test requires screen capture permission
        if let img = image {
            XCTAssertGreaterThan(img.width, 0)
            XCTAssertGreaterThan(img.height, 0)
        }
        // If nil, likely no permission — that's OK for CI
    }
    
    // MARK: - Video Writer with Various Frame Rates
    
    func testVideoWriterAllSupportedFrameRates() throws {
        let tempDir = TestHelper.createTempDirectory()
        defer { TestHelper.removeTempDirectory(tempDir) }
        
        for frameRate in [24, 30, 60] {
            let url = tempDir.appendingPathComponent("test_\(frameRate)fps.mp4")
            let writer = VideoWriter()
            try writer.startWriting(to: url, width: 100, height: 100, frameRate: frameRate)
            
            guard let image = TestHelper.createTestImage(width: 100, height: 100) else {
                XCTFail("Failed to create image")
                return
            }
            
            for i in 0..<frameRate {
                try writer.appendFrame(image, at: CMTime(value: CMTimeValue(i), timescale: CMTimeScale(frameRate)))
                Thread.sleep(forTimeInterval: 0.005)
            }
            
            let expectation = XCTestExpectation(description: "\(frameRate)fps finish")
            writer.finishWriting { result in
                if case .failure(let error) = result {
                    XCTFail("\(frameRate)fps failed: \(error)")
                }
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 5.0)
            
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "\(frameRate)fps output should exist")
        }
    }
    
    // MARK: - Error Handling
    
    func testMockVideoWriterFailurePath() {
        let mock = MockVideoWriter()
        mock.shouldFailOnStart = true
        
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("fail.mp4")
        XCTAssertThrowsError(try mock.startWriting(to: url, width: 100, height: 100, frameRate: 30))
    }
    
    func testCaptureWithInvalidRect() {
        let engine = ScreenCaptureEngine()
        engine.captureRect = .zero
        
        var errorReceived = false
        engine.onError = { _ in errorReceived = true }
        engine.startCapture()
        
        XCTAssertTrue(errorReceived)
        XCTAssertFalse(engine.isCapturing)
    }
    
    // MARK: - Recording Border Window
    
    func testRecordingBorderViewDraws() {
        let borderView = RecordingBorderView(frame: NSRect(x: 0, y: 0, width: 200, height: 150))
        XCTAssertTrue(borderView.wantsLayer)
    }
}

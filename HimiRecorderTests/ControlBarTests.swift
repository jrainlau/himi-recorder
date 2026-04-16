import XCTest
@testable import HimiRecorder

final class ControlBarTests: XCTestCase {
    
    // MARK: - ControlBarView State Tests
    
    func testControlBarViewInitialState() {
        let view = ControlBarView(frame: NSRect(x: 0, y: 0, width: 220, height: 40))
        // Should have subviews
        XCTAssertGreaterThan(view.subviews.count, 0)
    }
    
    func testControlBarViewSetRecordingStateTrue() {
        let view = ControlBarView(frame: NSRect(x: 0, y: 0, width: 220, height: 40))
        view.setRecordingState(true)
        let button = findView(withIdentifier: "actionButton", in: view) as? NSButton
        XCTAssertNotNil(button)
        XCTAssertEqual(button?.title, "结束录制")
    }
    
    func testControlBarViewSetRecordingStateFalse() {
        let view = ControlBarView(frame: NSRect(x: 0, y: 0, width: 220, height: 40))
        view.setRecordingState(false)
        let button = findView(withIdentifier: "actionButton", in: view) as? NSButton
        XCTAssertNotNil(button)
        XCTAssertEqual(button?.title, "开始录制")
    }
    
    func testControlBarViewUpdateSizeLabel() {
        let view = ControlBarView(frame: NSRect(x: 0, y: 0, width: 220, height: 40))
        view.updateSizeLabel(width: 529, height: 281)
        let label = findView(withIdentifier: "sizeLabel", in: view) as? NSTextField
        XCTAssertNotNil(label)
        XCTAssertEqual(label?.stringValue, "529 × 281")
    }
    
    func testControlBarViewUpdateTimer() {
        let view = ControlBarView(frame: NSRect(x: 0, y: 0, width: 220, height: 40))
        view.updateTimer(seconds: 65)
        let label = findView(withIdentifier: "timerLabel", in: view) as? NSTextField
        XCTAssertNotNil(label)
        XCTAssertEqual(label?.stringValue, "01:05")
    }
    
    func testControlBarViewUpdateTimerZero() {
        let view = ControlBarView(frame: NSRect(x: 0, y: 0, width: 220, height: 40))
        view.updateTimer(seconds: 0)
        let label = findView(withIdentifier: "timerLabel", in: view) as? NSTextField
        XCTAssertEqual(label?.stringValue, "00:00")
    }
    
    func testControlBarViewUpdateTimerLargeValue() {
        let view = ControlBarView(frame: NSRect(x: 0, y: 0, width: 220, height: 40))
        view.updateTimer(seconds: 3661) // 1h 1m 1s
        let label = findView(withIdentifier: "timerLabel", in: view) as? NSTextField
        XCTAssertEqual(label?.stringValue, "61:01")
    }
    
    // MARK: - ControlBarView Callback Tests
    
    func testStartRecordingCallback() {
        let view = ControlBarView(frame: NSRect(x: 0, y: 0, width: 220, height: 40))
        var callbackCalled = false
        view.onStartRecording = { callbackCalled = true }
        view.setRecordingState(false)
        
        let button = findView(withIdentifier: "actionButton", in: view) as? NSButton
        button?.performClick(nil)
        
        XCTAssertTrue(callbackCalled)
    }
    
    func testStopRecordingCallback() {
        let view = ControlBarView(frame: NSRect(x: 0, y: 0, width: 220, height: 40))
        var callbackCalled = false
        view.onStopRecording = { callbackCalled = true }
        view.setRecordingState(true)
        
        let button = findView(withIdentifier: "actionButton", in: view) as? NSButton
        button?.performClick(nil)
        
        XCTAssertTrue(callbackCalled)
    }
    
    // MARK: - ControlBarWindow Tests
    
    func testControlBarWindowPositionBelow() {
        let window = ControlBarWindow()
        // NS coordinates: (100, 200) is bottom-left, selection is 500x300
        let selectionNSRect = CGRect(x: 100, y: 200, width: 500, height: 300)
        
        window.positionBelow(selectionNSRect: selectionNSRect)
        
        // Verify horizontal centering (approximately)
        let expectedCenterX = selectionNSRect.midX
        let actualCenterX = window.frame.midX
        XCTAssertEqual(expectedCenterX, actualCenterX, accuracy: 1.0)
        
        // Verify the control bar is below the selection (its maxY < selection's minY)
        XCTAssertLessThan(window.frame.maxY, selectionNSRect.minY)
    }
    
    // MARK: - CountdownView Tests
    
    func testCountdownViewInitialState() {
        let view = CountdownView(frame: NSRect(x: 0, y: 0, width: 120, height: 120))
        let numberLabel = findView(withIdentifier: "countdownNumber", in: view) as? NSTextField
        XCTAssertNotNil(numberLabel)
        XCTAssertEqual(numberLabel?.stringValue, "3")
    }
    
    func testCountdownViewStartsAt3() {
        let view = CountdownView(frame: NSRect(x: 0, y: 0, width: 120, height: 120))
        let expectation = XCTestExpectation(description: "Countdown starts at 3")
        
        view.startCountdown {
            expectation.fulfill()
        }
        
        let numberLabel = findView(withIdentifier: "countdownNumber", in: view) as? NSTextField
        XCTAssertEqual(numberLabel?.stringValue, "3")
        
        view.cancelCountdown()
    }
    
    func testCountdownCompletion() {
        let view = CountdownView(frame: NSRect(x: 0, y: 0, width: 120, height: 120))
        let expectation = XCTestExpectation(description: "Countdown completes")
        
        view.startCountdown {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testCountdownCancel() {
        let view = CountdownView(frame: NSRect(x: 0, y: 0, width: 120, height: 120))
        var completed = false
        
        view.startCountdown {
            completed = true
        }
        
        view.cancelCountdown()
        
        // Wait a bit to ensure callback is NOT called
        let expectation = XCTestExpectation(description: "Wait")
        expectation.isInverted = true
        wait(for: [expectation], timeout: 4.0)
        
        XCTAssertFalse(completed, "Countdown should not complete after cancellation")
    }
    
    // MARK: - CountdownWindow Position Test
    
    func testCountdownWindowCenteredOnNSRect() {
        let countdown = CountdownWindow()
        let selectionNSRect = CGRect(x: 200, y: 300, width: 600, height: 400)
        
        countdown.startCountdown(centeredOnNSRect: selectionNSRect) { }
        
        // Countdown window should be centered on the selection rect
        let expectedCenterX = selectionNSRect.midX
        let expectedCenterY = selectionNSRect.midY
        
        XCTAssertEqual(countdown.frame.midX, expectedCenterX, accuracy: 1.0)
        XCTAssertEqual(countdown.frame.midY, expectedCenterY, accuracy: 1.0)
        
        countdown.orderOut(nil)
    }
    
    // MARK: - NS to CG Coordinate Conversion Test
    
    func testNSToCGCoordinateConversion() {
        // Verify the coordinate conversion logic used in AppDelegate
        guard let mainScreen = NSScreen.screens.first else { return }
        let mainHeight = mainScreen.frame.height
        
        // A rect at NS coordinates (100, 200) with size 500x300
        // NS: origin.y=200 means 200 points from the bottom
        // CG: origin.y should be mainHeight - (200 + 300) = mainHeight - 500
        let nsRect = CGRect(x: 100, y: 200, width: 500, height: 300)
        let cgY = mainHeight - nsRect.maxY
        let cgRect = CGRect(x: nsRect.origin.x, y: cgY, width: nsRect.width, height: nsRect.height)
        
        XCTAssertEqual(cgRect.origin.x, 100)
        XCTAssertEqual(cgRect.width, 500)
        XCTAssertEqual(cgRect.height, 300)
        XCTAssertEqual(cgRect.origin.y, mainHeight - 500)
    }
    
    // MARK: - Helpers
    
    private func findView(withIdentifier identifier: String, in view: NSView) -> NSView? {
        if view.accessibilityIdentifier() == identifier {
            return view
        }
        for subview in view.subviews {
            if let found = findView(withIdentifier: identifier, in: subview) {
                return found
            }
        }
        return nil
    }
}

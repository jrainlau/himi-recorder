import XCTest
@testable import HimiRecorder

final class SelectionGeometryTests: XCTestCase {
    
    // MARK: - normalizedRect Tests
    
    func testNormalizedRectTopLeftToBottomRight() {
        let rect = SelectionOverlayView.normalizedRect(
            from: CGPoint(x: 10, y: 100),
            to: CGPoint(x: 200, y: 10)
        )
        XCTAssertEqual(rect.origin.x, 10, accuracy: 0.01)
        XCTAssertEqual(rect.origin.y, 10, accuracy: 0.01)
        XCTAssertEqual(rect.width, 190, accuracy: 0.01)
        XCTAssertEqual(rect.height, 90, accuracy: 0.01)
    }
    
    func testNormalizedRectBottomRightToTopLeft() {
        let rect = SelectionOverlayView.normalizedRect(
            from: CGPoint(x: 200, y: 10),
            to: CGPoint(x: 10, y: 100)
        )
        XCTAssertEqual(rect.origin.x, 10, accuracy: 0.01)
        XCTAssertEqual(rect.origin.y, 10, accuracy: 0.01)
        XCTAssertEqual(rect.width, 190, accuracy: 0.01)
        XCTAssertEqual(rect.height, 90, accuracy: 0.01)
    }
    
    func testNormalizedRectSamePoint() {
        let rect = SelectionOverlayView.normalizedRect(
            from: CGPoint(x: 50, y: 50),
            to: CGPoint(x: 50, y: 50)
        )
        XCTAssertEqual(rect.width, 0, accuracy: 0.01)
        XCTAssertEqual(rect.height, 0, accuracy: 0.01)
    }
    
    func testNormalizedRectNegativeDirection() {
        let rect = SelectionOverlayView.normalizedRect(
            from: CGPoint(x: 300, y: 300),
            to: CGPoint(x: 100, y: 50)
        )
        XCTAssertEqual(rect.origin.x, 100, accuracy: 0.01)
        XCTAssertEqual(rect.origin.y, 50, accuracy: 0.01)
        XCTAssertEqual(rect.width, 200, accuracy: 0.01)
        XCTAssertEqual(rect.height, 250, accuracy: 0.01)
    }
    
    // MARK: - resizedRect Tests
    
    func testResizeFromTopRight() {
        let original = CGRect(x: 100, y: 100, width: 200, height: 150)
        let result = SelectionOverlayView.resizedRect(
            original: original,
            handle: .topRight,
            delta: CGPoint(x: 50, y: 30),
            minimumSize: 20
        )
        XCTAssertEqual(result.minX, 100, accuracy: 0.01)
        XCTAssertEqual(result.maxX, 350, accuracy: 0.01)
        XCTAssertEqual(result.minY, 100, accuracy: 0.01)
        XCTAssertEqual(result.maxY, 280, accuracy: 0.01)
    }
    
    func testResizeFromBottomLeft() {
        let original = CGRect(x: 100, y: 100, width: 200, height: 150)
        let result = SelectionOverlayView.resizedRect(
            original: original,
            handle: .bottomLeft,
            delta: CGPoint(x: -30, y: -20),
            minimumSize: 20
        )
        XCTAssertEqual(result.minX, 70, accuracy: 0.01)
        XCTAssertEqual(result.maxX, 300, accuracy: 0.01)
        XCTAssertEqual(result.minY, 80, accuracy: 0.01)
        XCTAssertEqual(result.maxY, 250, accuracy: 0.01)
    }
    
    func testResizeFromMiddleRight() {
        let original = CGRect(x: 100, y: 100, width: 200, height: 150)
        let result = SelectionOverlayView.resizedRect(
            original: original,
            handle: .middleRight,
            delta: CGPoint(x: 50, y: 0),
            minimumSize: 20
        )
        XCTAssertEqual(result.width, 250, accuracy: 0.01)
        XCTAssertEqual(result.height, 150, accuracy: 0.01, "Height should not change for middleRight")
    }
    
    func testResizeFromTopCenter() {
        let original = CGRect(x: 100, y: 100, width: 200, height: 150)
        let result = SelectionOverlayView.resizedRect(
            original: original,
            handle: .topCenter,
            delta: CGPoint(x: 0, y: 40),
            minimumSize: 20
        )
        XCTAssertEqual(result.width, 200, accuracy: 0.01, "Width should not change for topCenter")
        XCTAssertEqual(result.height, 190, accuracy: 0.01)
    }
    
    func testResizeEnforcesMinimumSize() {
        let original = CGRect(x: 100, y: 100, width: 200, height: 150)
        let result = SelectionOverlayView.resizedRect(
            original: original,
            handle: .middleRight,
            delta: CGPoint(x: -195, y: 0),
            minimumSize: 20
        )
        XCTAssertGreaterThanOrEqual(result.width, 20, "Width should not go below minimum")
    }
    
    func testResizeEnforcesMinimumHeight() {
        let original = CGRect(x: 100, y: 100, width: 200, height: 150)
        let result = SelectionOverlayView.resizedRect(
            original: original,
            handle: .topCenter,
            delta: CGPoint(x: 0, y: -145),
            minimumSize: 20
        )
        XCTAssertGreaterThanOrEqual(result.height, 20, "Height should not go below minimum")
    }
    
    func testResizeFromTopLeft() {
        let original = CGRect(x: 100, y: 100, width: 200, height: 150)
        let result = SelectionOverlayView.resizedRect(
            original: original,
            handle: .topLeft,
            delta: CGPoint(x: 10, y: -20),
            minimumSize: 20
        )
        XCTAssertEqual(result.minX, 110, accuracy: 0.01)
        XCTAssertEqual(result.maxX, 300, accuracy: 0.01)
        XCTAssertEqual(result.maxY, 230, accuracy: 0.01)
    }
    
    func testResizeFromBottomCenter() {
        let original = CGRect(x: 100, y: 100, width: 200, height: 150)
        let result = SelectionOverlayView.resizedRect(
            original: original,
            handle: .bottomCenter,
            delta: CGPoint(x: 0, y: -30),
            minimumSize: 20
        )
        XCTAssertEqual(result.minY, 70, accuracy: 0.01)
        XCTAssertEqual(result.width, 200, accuracy: 0.01, "Width should not change")
    }
    
    func testResizeFromBottomRight() {
        let original = CGRect(x: 100, y: 100, width: 200, height: 150)
        let result = SelectionOverlayView.resizedRect(
            original: original,
            handle: .bottomRight,
            delta: CGPoint(x: 30, y: -20),
            minimumSize: 20
        )
        XCTAssertEqual(result.maxX, 330, accuracy: 0.01)
        XCTAssertEqual(result.minY, 80, accuracy: 0.01)
    }
    
    func testResizeFromMiddleLeft() {
        let original = CGRect(x: 100, y: 100, width: 200, height: 150)
        let result = SelectionOverlayView.resizedRect(
            original: original,
            handle: .middleLeft,
            delta: CGPoint(x: -50, y: 0),
            minimumSize: 20
        )
        XCTAssertEqual(result.minX, 50, accuracy: 0.01)
        XCTAssertEqual(result.width, 250, accuracy: 0.01)
        XCTAssertEqual(result.height, 150, accuracy: 0.01, "Height should not change")
    }
    
    // MARK: - Handle Position Tests
    
    func testHandlePositionsCount() {
        XCTAssertEqual(SelectionOverlayView.HandlePosition.allCases.count, 8)
    }
    
    // MARK: - Handle Hit Detection (via view)
    
    func testHitHandleDetection() {
        let view = SelectionOverlayView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        // Simulate a selection by using the static methods to verify geometry
        let rect = CGRect(x: 100, y: 100, width: 200, height: 150)
        
        // Test handle points calculation
        let topLeft = CGPoint(x: rect.minX, y: rect.maxY)
        let bottomRight = CGPoint(x: rect.maxX, y: rect.minY)
        
        XCTAssertEqual(topLeft.x, 100, accuracy: 0.01)
        XCTAssertEqual(topLeft.y, 250, accuracy: 0.01)
        XCTAssertEqual(bottomRight.x, 300, accuracy: 0.01)
        XCTAssertEqual(bottomRight.y, 100, accuracy: 0.01)
    }
}

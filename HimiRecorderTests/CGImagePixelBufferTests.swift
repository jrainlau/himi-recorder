import XCTest
@testable import HimiRecorder

final class CGImagePixelBufferTests: XCTestCase {
    
    func testCreateTestImage() {
        let image = TestHelper.createTestImage(width: 200, height: 100)
        XCTAssertNotNil(image)
        XCTAssertEqual(image?.width, 200)
        XCTAssertEqual(image?.height, 100)
    }
    
    func testImageToPixelBuffer() {
        guard let image = TestHelper.createTestImage(width: 100, height: 80) else {
            XCTFail("Failed to create test image")
            return
        }
        
        let pixelBuffer = image.toPixelBuffer()
        XCTAssertNotNil(pixelBuffer)
        
        if let buffer = pixelBuffer {
            XCTAssertEqual(CVPixelBufferGetWidth(buffer), 100)
            XCTAssertEqual(CVPixelBufferGetHeight(buffer), 80)
        }
    }
    
    func testImageToPixelBufferWithCustomSize() {
        guard let image = TestHelper.createTestImage(width: 100, height: 100) else {
            XCTFail("Failed to create test image")
            return
        }
        
        let pixelBuffer = image.toPixelBuffer(width: 200, height: 150)
        XCTAssertNotNil(pixelBuffer)
        
        if let buffer = pixelBuffer {
            XCTAssertEqual(CVPixelBufferGetWidth(buffer), 200)
            XCTAssertEqual(CVPixelBufferGetHeight(buffer), 150)
        }
    }
    
    func testCreatePixelBufferPool() {
        let pool = CGImage.createPixelBufferPool(width: 640, height: 480)
        XCTAssertNotNil(pool)
    }
    
    func testImageToPixelBufferWithPool() {
        guard let pool = CGImage.createPixelBufferPool(width: 100, height: 100),
              let image = TestHelper.createTestImage(width: 100, height: 100) else {
            XCTFail("Failed to create pool or image")
            return
        }
        
        let pixelBuffer = image.toPixelBuffer(pool: pool, width: 100, height: 100)
        XCTAssertNotNil(pixelBuffer)
        
        if let buffer = pixelBuffer {
            XCTAssertEqual(CVPixelBufferGetWidth(buffer), 100)
            XCTAssertEqual(CVPixelBufferGetHeight(buffer), 100)
        }
    }
    
    func testMultipleFramesFromPool() {
        guard let pool = CGImage.createPixelBufferPool(width: 50, height: 50),
              let image = TestHelper.createTestImage(width: 50, height: 50) else {
            XCTFail("Setup failed")
            return
        }
        
        // Create multiple pixel buffers from pool to verify reuse
        for _ in 0..<10 {
            let buffer = image.toPixelBuffer(pool: pool, width: 50, height: 50)
            XCTAssertNotNil(buffer)
        }
    }
}

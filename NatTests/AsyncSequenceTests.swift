import XCTest
@testable import Nat

final class AsyncSequenceTests: XCTestCase {
    func testThrottle() async throws {
        // Test setup
        let expectation = XCTestExpectation(description: "Throttle test completed")
        let timeInterval: TimeInterval = 0.1 // 100ms throttle interval
        
        // Create a stream of rapidly emitted elements
        let stream = AsyncStream<Int> { continuation in
            Task {
                // Emit 10 values with no delay between them
                for i in 0..<10 {
                    continuation.yield(i)
                }
                continuation.finish()
            }
        }
        
        // Apply throttling
        let throttledStream = stream.throttle(for: timeInterval)
        
        let startTime = Date()
        
        // Collect all emitted values
        var emittedValues: [Int] = []
        var emissionTimes: [TimeInterval] = []
        
        for try await value in throttledStream {
            let currentTime = Date()
            let elapsed = currentTime.timeIntervalSince(startTime)
            
            emittedValues.append(value)
            emissionTimes.append(elapsed)
            
            // Add a small delay to simulate processing
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
        
        // Verify throttling behavior
        var passedThrottleCheck = true
        if emissionTimes.count >= 2 {
            for i in 1..<emissionTimes.count {
                let timeDiff = emissionTimes[i] - emissionTimes[i-1]
                
                // Allow a small margin of error (10ms) for time measurement
                if i < emissionTimes.count - 1 && timeDiff < (timeInterval - 0.01) {
                    passedThrottleCheck = false
                }
            }
        }
        
        expectation.fulfill()
        
        // Ensure the test waits for the async operation
        await fulfillment(of: [expectation], timeout: 3.0)
        
        XCTAssertTrue(passedThrottleCheck, "Throttling behavior check failed")
        XCTAssertEqual(emittedValues.last, 9, "Last value should be emitted")
    }
}

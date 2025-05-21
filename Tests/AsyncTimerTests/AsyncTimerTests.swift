@testable import AsyncTimer
import Foundation
import Testing

// MARK: - AsyncTimerTests

@Suite struct AsyncTimerTests {
    // MARK: - One-time Timer Tests

    @MainActor
    @Test func oneTimeTimer() async throws {
        var count = 0
        let timer = AsyncTimer(
            interval: 0.1,
            repeating: false,
            handler: {
                @MainActor in
                count += 1
            }
        )

        await timer.start()
        try await Task.sleep(nanoseconds: UInt64(0.2 * 1_000_000_000))

        #expect(count == 1, "One-time timer should execute exactly once")
    }

    // MARK: - Repeating Timer Tests

    @MainActor
    @Test func repeatingTimer() async throws {
        var count = 0
        let timer = AsyncTimer(
            interval: 0.1,
            repeating: true,
            firesImmediately: false,
            handler: {
                @MainActor in
                count += 1
            }
        )

        await timer.start()
        try await Task.sleep(nanoseconds: UInt64(0.35 * 1_000_000_000))
        await timer.stop()

        #expect(count >= 3, "Repeating timer should execute at least 3 times")
    }

    // MARK: - Fires Immediately Tests

    @MainActor
    @Test func testFiresImmediately() async throws {
        var executionTimes: [TimeInterval] = []
        let startTime = Date().timeIntervalSince1970

        let timer = AsyncTimer(
            interval: 0.1,
            repeating: true,
            firesImmediately: true,
            handler: {
                @MainActor in
                executionTimes.append(Date().timeIntervalSince1970 - startTime)
            }
        )

        await timer.start()
        try await Task.sleep(nanoseconds: UInt64(0.15 * 1_000_000_000))
        await timer.stop()

        #expect(!executionTimes.isEmpty, "Timer should execute at least once")
        #expect(executionTimes[0] < 0.01, "First execution should happen almost immediately")
    }

    // MARK: - Set Interval Tests

    @MainActor
    @Test func testSetInterval() async throws {
        var executionTimes: [TimeInterval] = []
        let startTime = Date().timeIntervalSince1970

        let timer = AsyncTimer(
            interval: 0.2,
            repeating: true,
            handler: {
                @MainActor in
                executionTimes.append(Date().timeIntervalSince1970 - startTime)
            }
        )

        await timer.start()
        try await Task.sleep(nanoseconds: UInt64(0.3 * 1_000_000_000))
        await timer.setInterval(0.1)
        try await Task.sleep(nanoseconds: UInt64(0.2 * 1_000_000_000))
        await timer.stop()

        let intervals = zip(executionTimes, executionTimes.dropFirst())
            .map { $1 - $0 }

        #expect(intervals.contains { $0 < 0.15 }, "Intervals should become shorter after setting new interval")
    }

    // MARK: - Stop/Restart Tests

    @MainActor
    @Test func stopAndRestart() async throws {
        var count = 0
        let timer = AsyncTimer(
            interval: 0.1,
            repeating: true,
            handler: {
                @MainActor in
                count += 1
            }
        )

        await timer.start()
        try await Task.sleep(nanoseconds: UInt64(0.15 * 1_000_000_000))
        await timer.stop()
        let countAfterStop = count
        try await Task.sleep(nanoseconds: UInt64(0.2 * 1_000_000_000))
        #expect(count == countAfterStop, "Count should not increase after stopping")

        await timer.restart()
        try await Task.sleep(nanoseconds: UInt64(0.15 * 1_000_000_000))
        #expect(count > countAfterStop, "Count should increase after restarting")
    }

    // MARK: - Cancel Handler Tests

    @MainActor
    @Test func testCancelHandler() async throws {
        var handlerExecuted = false
        var cancelHandlerExecuted = false

        let timer = AsyncTimer(
            interval: 0.1,
            repeating: true,
            handler: {
                @MainActor in
                handlerExecuted = true
            },
            cancelHandler: {
                @MainActor in
                cancelHandlerExecuted = true
            }
        )

        await timer.start()
        try await Task.sleep(nanoseconds: UInt64(0.15 * 1_000_000_000))
        await timer.stop()
        try await Task.sleep(nanoseconds: UInt64(0.05 * 1_000_000_000)) // Give time for cancel handler to execute

        #expect(handlerExecuted, "Timer handler should have executed")
        #expect(cancelHandlerExecuted, "Cancel handler should have executed after stopping the timer")
    }

    // MARK: - Task Priority Tests

    @MainActor
    @Test func taskPriority() async throws {
        var highPriorityExecutionTime: TimeInterval = 0
        var lowPriorityExecutionTime: TimeInterval = 0
        let startTime = Date().timeIntervalSince1970

        // Create a high priority timer
        let highPriorityTimer = AsyncTimer(
            interval: 0.1,
            priority: .high,
            repeating: false,
            handler: {
                @MainActor in
                // Simulate some work
                for _ in 0..<1000000 {
                    _ = 1 + 1
                }
                highPriorityExecutionTime = Date().timeIntervalSince1970 - startTime
            }
        )

        // Create a low priority timer
        let lowPriorityTimer = AsyncTimer(
            interval: 0.1,
            priority: .low,
            repeating: false,
            handler: {
                @MainActor in
                // Simulate some work
                for _ in 0..<1000000 {
                    _ = 1 + 1
                }
                lowPriorityExecutionTime = Date().timeIntervalSince1970 - startTime
            }
        )

        // Start both timers at the same time
        await lowPriorityTimer.start()
        await highPriorityTimer.start()

        // Wait for both to complete
        try await Task.sleep(nanoseconds: UInt64(0.3 * 1_000_000_000))

        // Note: This test is probabilistic and may not always pass
        // In a heavily loaded system, the scheduler might not respect priorities as expected
        #expect(highPriorityExecutionTime <= lowPriorityExecutionTime, "High priority timer should execute before or at the same time as low priority timer")
    }

    // MARK: - Multiple Timers Test

    @MainActor
    @Test func multipleTimers() async throws {
        var counts = [0, 0, 0]

        let timer1 = AsyncTimer(
            interval: 0.05,
            repeating: true,
            handler: {
                @MainActor in
                counts[0] += 1
            }
        )

        let timer2 = AsyncTimer(
            interval: 0.07,
            repeating: true,
            handler: {
                @MainActor in
                counts[1] += 1
            }
        )

        let timer3 = AsyncTimer(
            interval: 0.03,
            repeating: true,
            handler: {
                @MainActor in
                counts[2] += 1
            }
        )

        // Start all timers
        await timer1.start()
        await timer2.start()
        await timer3.start()

        // Let them run for a while
        try await Task.sleep(nanoseconds: UInt64(0.3 * 1_000_000_000))

        // Stop all timers
        await timer1.stop()
        await timer2.stop()
        await timer3.stop()

        // Check that all timers executed
        #expect(counts[0] > 0, "Timer 1 should have executed")
        #expect(counts[1] > 0, "Timer 2 should have executed")
        #expect(counts[2] > 0, "Timer 3 should have executed")

        // Timer3 should have executed more times than timer1, which should have executed more times than timer2
        #expect(counts[2] > counts[0], "Timer with shorter interval should execute more times")
        #expect(counts[0] > counts[1], "Timer with shorter interval should execute more times")
    }
}

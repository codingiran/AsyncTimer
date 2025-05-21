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
}

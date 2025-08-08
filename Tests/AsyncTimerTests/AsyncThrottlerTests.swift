@testable import AsyncTimer
import Foundation
import Testing

@Suite struct AsyncThrottlerTests {
    // MARK: - Leading Only

    @MainActor
    @Test func leadingOnly_basic() async throws {
        var count = 0
        let throttler = AsyncThrottler(
            throttleTime: .seconds(0.1),
            behavior: .leadingOnly
        )

        // Burst of calls within the same window → only the first executes
        await throttler.call {
            @MainActor in count += 1
        }
        try await Task.sleep(nanoseconds: UInt64(0.02 * 1_000_000_000))
        await throttler.call {
            @MainActor in count += 1
        }
        await throttler.call {
            @MainActor in count += 1
        }

        // Wait for the window to end
        try await Task.sleep(nanoseconds: UInt64(0.12 * 1_000_000_000))
        #expect(count == 1, "Leading-only should execute immediately once within the window")

        // Next call after window should execute again
        await throttler.call {
            @MainActor in count += 1
        }
        #expect(count == 2, "Next window leading should execute again")
    }

    // MARK: - Trailing Only

    @MainActor
    @Test func trailingOnly_basic() async throws {
        var count = 0
        let throttler = AsyncThrottler(
            throttleTime: .seconds(0.1),
            behavior: .trailingOnly
        )

        // Burst of calls within the same window → only one trailing execution at window end
        await throttler.call {
            @MainActor in count += 1
        }
        try await Task.sleep(nanoseconds: UInt64(0.02 * 1_000_000_000))
        await throttler.call {
            @MainActor in count += 1
        }
        await throttler.call {
            @MainActor in count += 1
        }

        // Before window end, nothing should have executed
        #expect(count == 0, "Trailing-only should not execute before window end")

        // Wait slightly longer than the interval for trailing execution
        try await Task.sleep(nanoseconds: UInt64(0.12 * 1_000_000_000))
        #expect(count == 1, "Trailing-only should execute once at window end")
    }

    // MARK: - Leading And Trailing

    @MainActor
    @Test func leadingAndTrailing_basic() async throws {
        var count = 0
        let throttler = AsyncThrottler(
            throttleTime: .seconds(0.1),
            behavior: .leadingAndTrailing
        )

        await throttler.call {
            @MainActor in count += 1
        } // leading fires

        // Another call within the window should schedule a trailing execution
        try await Task.sleep(nanoseconds: UInt64(0.05 * 1_000_000_000))
        await throttler.call {
            @MainActor in count += 1
        }

        // Wait for trailing to fire
        try await Task.sleep(nanoseconds: UInt64(0.12 * 1_000_000_000))
        #expect(count == 2, "Leading+Trailing should execute at both edges when additional calls occur within the window")
    }

    // MARK: - Cancel

    @MainActor
    @Test func cancel_clearsPendingAndStopsWindow() async throws {
        var count = 0
        let throttler = AsyncThrottler(
            throttleTime: .seconds(0.1),
            behavior: .trailingOnly
        )

        await throttler.call {
            @MainActor in count += 1
        }
        // Cancel before trailing fires
        await throttler.cancel()
        try await Task.sleep(nanoseconds: UInt64(0.12 * 1_000_000_000))
        #expect(count == 0, "Cancel should prevent trailing execution")
    }

    // MARK: - Zero Interval

    @MainActor
    @Test func zeroInterval_executesImmediately() async throws {
        var count = 0
        let throttler = AsyncThrottler(
            throttleTime: .seconds(0),
            behavior: .leadingAndTrailing
        )

        // Multiple calls should all execute immediately (no throttling)
        await throttler.call { @MainActor in count += 1 }
        await throttler.call { @MainActor in count += 1 }
        await throttler.call { @MainActor in count += 1 }

        #expect(count == 3, "Zero interval should bypass throttling and execute all calls")
    }

    // MARK: - Cadence (drift vs antiDrift)

    @MainActor
    @Test func cadence_drift_alignment_basic() async throws {
        // Configuration: longer interval to reduce relative scheduler noise
        let interval: TimeInterval = 0.1
        let genInterval: TimeInterval = 0.003

        func run(cadence: AsyncThrottler.ThrottleCadence) async -> [TimeInterval] {
            var times: [TimeInterval] = []
            let start = Date().timeIntervalSince1970
            let throttler = AsyncThrottler(
                throttleTime: .seconds(interval),
                behavior: .trailingOnly,
                cadence: cadence
            )
            let generator = Task {
                for _ in 0 ..< 200 {
                    await throttler.call { @MainActor in times.append(Date().timeIntervalSince1970 - start) }
                    try? await Task.sleep(nanoseconds: UInt64(genInterval * 1_000_000_000))
                }
            }
            try? await Task.sleep(nanoseconds: UInt64((interval * 14) * 1_000_000_000))
            generator.cancel()
            await throttler.cancel()
            return times
        }

        func meanAbsError(_ arr: [TimeInterval], target: TimeInterval) -> Double {
            guard !arr.isEmpty else { return .infinity }
            return arr.map { abs($0 - target) }.reduce(0, +) / Double(arr.count)
        }
        func deltas(_ arr: [TimeInterval]) -> [TimeInterval] {
            guard arr.count >= 2 else { return [] }
            return zip(arr, arr.dropFirst()).map { $1 - $0 }
        }

        let times = await run(cadence: .antiDrift)
        #expect(times.count >= 6, "Should produce enough executions")
        let ds = deltas(Array(times.prefix(12)))
        let mae = meanAbsError(ds, target: interval)
        #expect(mae <= 0.03, "Cadence should align period close to interval")
    }

    @MainActor
    @Test func cadence_antiDrift_alignment_basic() async throws {
        // Same assertion as drift basic to ensure both modes produce reasonable cadence
        let interval: TimeInterval = 0.1
        let genInterval: TimeInterval = 0.003
        var times: [TimeInterval] = []
        let start = Date().timeIntervalSince1970
        let throttler = AsyncThrottler(
            throttleTime: .seconds(interval),
            behavior: .trailingOnly,
            cadence: .drift
        )
        let generator = Task {
            for _ in 0 ..< 200 {
                await throttler.call { @MainActor in times.append(Date().timeIntervalSince1970 - start) }
                try? await Task.sleep(nanoseconds: UInt64(genInterval * 1_000_000_000))
            }
        }
        try await Task.sleep(nanoseconds: UInt64((interval * 14) * 1_000_000_000))
        generator.cancel()
        await throttler.cancel()

        func deltas(_ arr: [TimeInterval]) -> [TimeInterval] {
            guard arr.count >= 2 else { return [] }
            return zip(arr, arr.dropFirst()).map { $1 - $0 }
        }
        func meanAbsError(_ arr: [TimeInterval], target: TimeInterval) -> Double {
            guard !arr.isEmpty else { return .infinity }
            return arr.map { abs($0 - target) }.reduce(0, +) / Double(arr.count)
        }
        #expect(times.count >= 6, "Should produce enough executions")
        let ds = deltas(Array(times.prefix(12)))
        let mae = meanAbsError(ds, target: interval)
        #expect(mae <= 0.03, "Cadence should align period close to interval")
    }
}

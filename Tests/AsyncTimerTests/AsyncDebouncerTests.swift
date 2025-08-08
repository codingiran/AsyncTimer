@testable import AsyncTimer
import Foundation
import Testing

@Suite struct AsyncDebouncerTests {
    // MARK: - Basic debounce (trailing)

    @MainActor
    @Test func basic_debounce_trailing_executes_once() async throws {
        var count = 0
        let debouncer = AsyncDebouncer(debounceTime: .seconds(0.05))

        await debouncer.call {
            @MainActor in count += 1
        }
        try await Task.sleep(nanoseconds: UInt64(0.01 * 1_000_000_000))
        await debouncer.call {
            @MainActor in count += 1
        }
        try await Task.sleep(nanoseconds: UInt64(0.01 * 1_000_000_000))
        await debouncer.call {
            @MainActor in count += 1
        }

        // Wait slightly longer than debounce time; should only fire once
        try await Task.sleep(nanoseconds: UInt64(0.07 * 1_000_000_000))
        #expect(count == 1, "Debouncer should execute only once after the last call")
    }

    // MARK: - Cancel

    @MainActor
    @Test func cancel_prevents_execution() async throws {
        var count = 0
        let debouncer = AsyncDebouncer(debounceTime: .seconds(0.05))

        await debouncer.call {
            @MainActor in count += 1
        }
        // Cancel before the debounce window elapses
        await debouncer.cancel()
        try await Task.sleep(nanoseconds: UInt64(0.06 * 1_000_000_000))
        #expect(count == 0, "Cancel should prevent the scheduled execution")
    }

    // MARK: - Override debounce time per call

    @MainActor
    @Test func override_debounce_time_per_call() async throws {
        var firedAt: TimeInterval = 0
        let start = Date().timeIntervalSince1970
        let debouncer = AsyncDebouncer(debounceTime: .seconds(0.2))

        await debouncer.call(debounceTime: .seconds(0.05)) {
            @MainActor in firedAt = Date().timeIntervalSince1970 - start
        }

        try await Task.sleep(nanoseconds: UInt64(0.07 * 1_000_000_000))
        #expect(firedAt > 0, "Handler should have fired")
        #expect(firedAt < 0.12, "Override should shorten debounce significantly")
    }

    // MARK: - isWaiting state

    @MainActor
    @Test func isWaiting_reflects_pending_state() async throws {
        let debouncer = AsyncDebouncer(debounceTime: .seconds(0.05))

        await debouncer.call {}
        // Give the actor a tick to schedule the timer
        await Task.yield()

        let waiting1 = await debouncer.isWaiting
        #expect(waiting1, "Debouncer should be waiting during the debounce window")

        // After firing, it should no longer be waiting
        try await Task.sleep(nanoseconds: UInt64(0.07 * 1_000_000_000))
        let waiting2 = await debouncer.isWaiting
        #expect(!waiting2, "Debouncer should not be waiting after the handler fires")
    }

    // MARK: - Zero interval executes immediately

    @MainActor
    @Test func zero_interval_executes_immediately() async throws {
        var count = 0
        let debouncer = AsyncDebouncer(debounceTime: .seconds(0))

        await debouncer.call { @MainActor in count += 1 }
        await debouncer.call { @MainActor in count += 1 }
        await debouncer.call { @MainActor in count += 1 }

        #expect(count == 3, "Zero interval should bypass debouncing and execute immediately")
    }
}

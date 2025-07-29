//
//  AsyncDebouncer.swift
//  AsyncTimer
//
//  Created by CodingIran on 2025/7/29.
//

import Foundation

public final actor AsyncDebouncer {
    /// Task handler
    public typealias DebounceHandler = @Sendable () async -> Void

    /// Debounce time.
    private var debounceTime: Interval

    /// Internal Timer.
    private var timer: AsyncTimer?

    /// Initializes a new `AsyncDebouncer` instance.
    /// - Parameter debounceTime: The debounce time.
    public init(debounceTime: Interval) {
        precondition(debounceTime.isValid, "Interval must be greater or equal to 0")
        self.debounceTime = debounceTime
    }

    deinit {
        timer = nil
    }

    /// Calls the debounce handler.
    /// - Parameters:
    ///   - debounceTime: Override the debounce time of initializes value.
    ///   - debounceHandler: The debounce handler.
    public func call(debounceTime: Interval? = nil,
                     debounceHandler: @escaping DebounceHandler) async
    {
        // Validate and update debounce time if provided
        if let debounceTime {
            precondition(debounceTime.isValid, "Interval must be greater or equal to 0")
            setDebounceTime(debounceTime)
        }

        // Cancel existing timer if running
        if let timer {
            await timer.stop()
            cleanupTimer()
        }

        // Handle zero or negative debounce time - execute immediately
        guard self.debounceTime.isPositive else {
            await debounceHandler()
            return
        }

        // Start new timer
        timer = AsyncTimer(interval: self.debounceTime,
                           repeating: false,
                           firesImmediately: false,
                           handler: { [weak self] in
                               await debounceHandler()
                               await self?.cleanupTimer()
                           })
        await timer?.start()
    }

    /// Cancels the current debounce operation.
    public func cancel() {
        cleanupTimer()
    }

    /// Whether the debouncer is currently waiting.
    public var isWaiting: Bool {
        timer != nil
    }

    /// Updates the debounce time.
    /// - Parameter newDebounceTime: The new debounce time.
    public func setDebounceTime(_ newDebounceTime: Interval) {
        precondition(newDebounceTime.isValid, "Interval must be greater or equal to 0")
        if debounceTime != newDebounceTime {
            debounceTime = newDebounceTime
        }
    }
}

private extension AsyncDebouncer {
    /// Cleans up the timer reference when the task completes.
    func cleanupTimer() {
        timer = nil
    }
}

//
//  AsyncTimer.swift
//  AsyncTimer
//
//  Created by CodingIran on 2025/5/20.
//

import Foundation

// Enforce minimum Swift version for all platforms and build systems.
#if swift(<5.9)
    #error("AsyncTimer doesn't support Swift versions below 5.9")
#endif

public enum AsyncTimerInfo: Sendable {
    /// Current AsyncTimer version.
    public static let version = "0.0.3"
}

/// A simple repeating timer that runs a task at a specified interval.
public final actor AsyncTimer {
    // MARK: - Properties

    /// Repeating task handler
    public typealias RepeatHandler = @Sendable () async -> Void

    /// Cancel handler
    public typealias CancelHandler = @Sendable () async -> Void

    /// The task that runs the repeating timer.
    private var task: Task<Void, Error>?

    /// The interval at which the timer fires.
    private var interval: TimeInterval

    /// The priority of the task.
    private let priority: TaskPriority

    /// Whether the timer should repeat.
    private let repeating: Bool

    /// Whether the timer should fire immediately upon starting.
    private let firesImmediately: Bool

    /// This handler is called when the timer fires.
    private var handler: RepeatHandler

    /// This handler is called when the timer is cancelled.
    private var cancelHandler: CancelHandler?

    /// Whether the timer is running.
    public var isRunning: Bool { task != nil }

    /// Initializes a new `AsyncTimer` instance.
    /// - Parameters:
    ///   - interval: The interval at which the timer fires.
    ///   - priority: The priority of the task. Default is `.medium`.
    ///   - repeating: Whether the timer should repeat. Default is `false`.
    ///   - firesImmediately: Whether the timer should fire immediately upon starting. Default is `true`. It is only effective when `repeating` is `true`.
    ///   - handler: The handler that is called when the timer fires.
    ///   - cancelHandler: The handler that is called when the timer is cancelled.
    /// - Returns: A new `AsyncTimer` instance.
    public init(interval: TimeInterval,
                priority: TaskPriority = .medium,
                repeating: Bool = false,
                firesImmediately: Bool = true,
                handler: @escaping RepeatHandler,
                cancelHandler: CancelHandler? = nil)
    {
        precondition(interval > 0, "Interval must be greater than 0")
        self.interval = interval
        self.priority = priority
        self.firesImmediately = firesImmediately
        self.repeating = repeating
        self.handler = handler
        self.cancelHandler = cancelHandler
    }

    /// Starts the timer.
    /// - Note: If the timer is already running, it will be stopped and restarted.
    public func start() {
        stop()
        task = Task(priority: priority) {
            guard repeating else {
                // one-time timer
                do {
                    try await Self.sleep(interval)
                    await self.handler()
                } catch is CancellationError {
                    // timer was cancelled
                    await cancelHandler?()
                }
                return
            }

            // repeating timer
            do {
                if !firesImmediately {
                    try await Self.sleep(interval)
                }
                while !Task.isCancelled {
                    await self.handler()
                    if Task.isCancelled { break }
                    try await Self.sleep(interval)
                }
            } catch is CancellationError {
                // timer was cancelled
            } catch {
                // unexpected error
            }
            await cancelHandler?()
        }
    }

    /// Stops the timer.
    public func stop() {
        guard let task else { return }
        task.cancel()
        self.task = nil
    }

    /// Restarts the timer.
    public func restart() {
        stop()
        start()
    }

    /// Modifies the interval of the timer.
    /// - Parameter newInterval: The new interval at which the timer should fire.
    /// - Note: This will also restart the timer.
    public func setInterval(_ newInterval: TimeInterval) {
        precondition(newInterval > 0, "Interval must be greater than 0")
        guard interval != newInterval else { return }
        interval = newInterval
        if isRunning { restart() }
    }
}

public extension AsyncTimer {
    /// Sleep for the specified interval.
    static func sleep(_ interval: TimeInterval) async throws {
        precondition(interval > 0, "Interval must be greater than 0")
        try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
    }
}

//
//  AsyncTimer.swift
//  AsyncTimer
//
//  Created by CodingIran on 2025/5/20.
//

import Foundation

// Enforce minimum Swift version for all platforms and build systems.
#if swift(<5.10)
    #error("AsyncTimer doesn't support Swift versions below 5.10")
#endif

public enum AsyncTimerInfo: Sendable {
    /// Current AsyncTimer version.
    public static let version = "0.0.5"
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
    private var interval: Interval

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
    public init(interval: Interval,
                priority: TaskPriority = .medium,
                repeating: Bool = false,
                firesImmediately: Bool = true,
                handler: @escaping RepeatHandler,
                cancelHandler: CancelHandler? = nil)
    {
        precondition(interval.isValid, "Interval must be greater or equal to 0")
        self.interval = interval
        self.priority = priority
        self.firesImmediately = firesImmediately
        self.repeating = repeating
        self.handler = handler
        self.cancelHandler = cancelHandler
    }

    deinit {
        task?.cancel()
        task = nil
    }

    /// Starts the timer.
    /// - Note: If the timer is already running, it will be stopped and restarted.
    public func start() {
        stop()
        task = Task(priority: priority) { [weak self] in
            guard let self else { return }

            // one-time timer
            guard repeating else {
                do {
                    try await Self.sleep(interval)
                    await handler()
                    await handleTaskCompletion()
                } catch {
                    // task was cancelled
                    await handleTaskCancelation()
                }
                return
            }

            // repeating timer
            do {
                if !firesImmediately {
                    try await Self.sleep(interval)
                }
                while !Task.isCancelled {
                    await handler()
                    if Task.isCancelled { break }
                    try await Self.sleep(interval)
                }
            } catch {
                // task was cancelled during sleep
            }
            // while loop was break or task cancelled
            await handleTaskCancelation()
        }
    }

    /// Stops the timer.
    public func stop() {
        task?.cancel()
        task = nil
    }

    /// Restarts the timer.
    public func restart() {
        stop()
        start()
    }

    /// Modifies the interval of the timer.
    /// - Parameter newInterval: The new interval at which the timer should fire.
    /// - Note: This will also restart the timer.
    public func setInterval(_ newInterval: Interval) {
        precondition(newInterval.isValid, "Interval must be greater or equal to 0")
        guard interval != newInterval else { return }
        interval = newInterval
        if isRunning { restart() }
    }
}

private extension AsyncTimer {
    /// Handles the task cancelation.
    func handleTaskCancelation() {
        task = nil
        Task { [weak self] in
            await self?.cancelHandler?()
        }
    }

    /// Handles the task completion.
    func handleTaskCompletion() {
        task = nil
    }
}

public extension AsyncTimer {
    /// Sleep for the specified interval.
    static func sleep(_ interval: Interval) async throws {
        precondition(interval.isValid, "Interval must be greater or equal to 0")
        try await Task.sleep(nanoseconds: interval.nanoseconds)
    }
}

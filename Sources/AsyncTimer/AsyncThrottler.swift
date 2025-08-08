//
//  AsyncThrottler.swift
//  AsyncTimer
//
//  Created by CodingIran on 2025/8/8.
//

import Dispatch
import Foundation

public final actor AsyncThrottler {
    // MARK: - Types

    public typealias ThrottleHandler = @Sendable () async -> Void

    /// Throttle behavior describing when to execute within a window.
    public enum ThrottleBehavior: Sendable {
        /// Execute at the beginning of the window.
        case leadingOnly
        /// Execute at the end of the window if there were calls during the window.
        case trailingOnly
        /// Execute at both ends of the window.
        case leadingAndTrailing
    }

    /// Cadence baseline policy for scheduling windows.
    public enum ThrottleCadence: Sendable {
        /// Drift scheduling: each window delay is exactly `interval` from now (may drift over time).
        case drift
        /// Anti-drift scheduling: windows align to a stable timeline `t0 + n * interval`.
        case antiDrift
    }

    // MARK: - Properties

    private var throttleTime: Interval
    private let behavior: ThrottleBehavior
    private let priority: TaskPriority
    private let cadence: ThrottleCadence

    private var cooldownTimer: AsyncTimer?
    private var pendingHandler: ThrottleHandler?
    private var lastScheduledDeadline: DispatchTime?

    /// Whether throttler is currently within a cooldown window.
    public var isThrottling: Bool { cooldownTimer != nil }

    // MARK: - Init

    /// Initializes a new `AsyncThrottler` instance.
    /// - Parameters:
    ///   - throttleTime: The throttle window.
    ///   - behavior: Execute at leading, trailing, or both ends of the window.
    ///   - cadence: Cadence baseline policy for scheduling windows.
    ///   - priority: Task priority used for internal scheduling.
    public init(throttleTime: Interval,
                behavior: ThrottleBehavior = .leadingAndTrailing,
                cadence: ThrottleCadence = .antiDrift,
                priority: TaskPriority = .medium)
    {
        precondition(throttleTime.isValid, "Interval must be greater or equal to 0")
        self.throttleTime = throttleTime
        self.behavior = behavior
        self.cadence = cadence
        self.priority = priority
    }

    deinit {
        // Rely on AsyncTimer's deinit to cancel its internal task.
        cooldownTimer = nil
        pendingHandler = nil
    }

    // MARK: - Public API

    /// Throttled call.
    /// - Parameters:
    ///   - throttleTime: Optional override of throttle window for this call.
    ///   - handler: The throttled handler to execute.
    public func call(throttleTime: Interval? = nil,
                     handler: @escaping ThrottleHandler) async
    {
        if let throttleTime {
            precondition(throttleTime.isValid, "Interval must be greater or equal to 0")
            setThrottleTime(throttleTime)
        }

        // Zero or non-positive → execute immediately, no throttling.
        guard self.throttleTime.isPositive else {
            await handler()
            return
        }

        // Not currently throttling (no active window)
        guard isThrottling else {
            if leading {
                // For anti-drift, fix cadence base to the moment we start this window (before handler work)
                if cadence == .antiDrift {
                    lastScheduledDeadline = DispatchTime.now()
                }
                await handler()
            } else if trailing {
                pendingHandler = handler
                // Base will be `now` for trailing-only on first window
                if cadence == .antiDrift {
                    lastScheduledDeadline = nil
                }
            }

            await startCooldownWindow()
            return
        }

        // Within cooldown window
        if trailing {
            pendingHandler = handler
        }
        // If trailing is false, we drop this call.
    }

    /// Cancels current throttle window and clears pending work.
    public func cancel() async {
        if let cooldownTimer {
            await cooldownTimer.stop()
            cleanupCooldown()
        }
        pendingHandler = nil
        lastScheduledDeadline = nil
    }

    /// Updates the throttle time. Does not restart the current window.
    public func setThrottleTime(_ newThrottleTime: Interval) {
        precondition(newThrottleTime.isValid, "Interval must be greater or equal to 0")
        guard throttleTime != newThrottleTime else { return }
        throttleTime = newThrottleTime
    }
}

// MARK: - Private

private extension AsyncThrottler {
    func startCooldownWindow() async {
        let intervalNs = throttleTime.nanoseconds
        let clampedInterval = UInt64(min(intervalNs, UInt64(Int.max)))

        let delayNs: UInt64
        switch cadence {
        case .drift:
            // Simple rolling window: always wait exactly interval from now.
            delayNs = clampedInterval
        case .antiDrift:
            // Align to stable timeline based on lastScheduledDeadline.
            let now = DispatchTime.now()
            let base = lastScheduledDeadline ?? now
            let next = base + .nanoseconds(Int(clampedInterval))
            lastScheduledDeadline = next
            delayNs = next.uptimeNanoseconds > now.uptimeNanoseconds
                ? (next.uptimeNanoseconds - now.uptimeNanoseconds)
                : 0
        }

        cooldownTimer = AsyncTimer(
            interval: .nanoseconds(delayNs),
            priority: priority,
            repeating: false,
            firesImmediately: false,
            handler: { [weak self] in
                await self?.onCooldownFired()
            },
            cancelHandler: { [weak self] in
                await self?.cleanupCooldown()
            }
        )
        await cooldownTimer?.start()
    }

    func onCooldownFired() async {
        // If there's pending work and trailing is enabled, execute it
        if trailing, let handler = pendingHandler {
            pendingHandler = nil
            await handler()
            // Continue with a new cooldown window to keep throttling cadence
            cleanupCooldown()
            await startCooldownWindow()
            return
        }

        // No pending work; end throttling window
        cleanupCooldown()
        lastScheduledDeadline = nil
    }

    func cleanupCooldown() {
        cooldownTimer = nil
    }

    var leading: Bool {
        switch behavior {
        case .leadingOnly, .leadingAndTrailing: return true
        case .trailingOnly: return false
        }
    }

    var trailing: Bool {
        switch behavior {
        case .trailingOnly, .leadingAndTrailing: return true
        case .leadingOnly: return false
        }
    }
}

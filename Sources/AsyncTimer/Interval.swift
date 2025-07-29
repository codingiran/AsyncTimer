//
//  Interval.swift
//  AsyncTimer
//
//  Created by CodingIran on 2025/7/29.
//

import Foundation

/// Interval wrapper for different time units.
public enum Interval: Sendable {
    /// Nanoseconds
    case nanoseconds(_: UInt64)
    /// Microseconds
    case microseconds(_: UInt64)
    /// Milliseconds
    case milliseconds(_: UInt64)
    /// Seconds
    case seconds(_: Double)
    /// Minutes
    case minutes(_: UInt64)

    /// Nanoseconds presentation.
    public var nanoseconds: UInt64 {
        switch self {
        case let .nanoseconds(value):
            return value
        case let .microseconds(value):
            return value * 1000
        case let .milliseconds(value):
            return value * 1_000_000
        case let .seconds(value):
            return UInt64(value * 1_000_000_000)
        case let .minutes(value):
            return value * 60 * 1_000_000_000
        }
    }

    /// Whether the interval is zero.
    public var isZero: Bool { nanoseconds == 0 }

    /// Whether the interval is positive.
    public var isPositive: Bool { nanoseconds > 0 }

    /// Whether the interval is negative.
    public var isNegative: Bool { nanoseconds < 0 }

    /// Whether the interval is valid.
    public var isValid: Bool { !isNegative }
}

extension Interval: Equatable {
    public static func == (lhs: Interval, rhs: Interval) -> Bool {
        lhs.nanoseconds == rhs.nanoseconds
    }
}

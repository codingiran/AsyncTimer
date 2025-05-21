# AsyncTimer

[![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%20|%20macOS%20|%20tvOS%20|%20watchOS%20|%20visionOS-blue.svg)](https://developer.apple.com)
[![Swift Package Manager](https://img.shields.io/badge/Swift_Package_Manager-compatible-brightgreen.svg)](https://swift.org/package-manager)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A lightweight, modern Swift async/await timer implementation for Apple platforms. AsyncTimer provides a clean, actor-based API for scheduling one-time and repeating tasks with precise control over timing, priorities, and cancellation.

## Features

- ✅ **Swift Concurrency** - Built with Swift's modern concurrency model using async/await and actors
- ✅ **Flexible Timing** - Support for one-time and repeating timers with configurable intervals
- ✅ **Task Priorities** - Set execution priorities for your timer tasks
- ✅ **Immediate Firing Option** - Configure timers to fire immediately or after the first interval
- ✅ **Cancellation Support** - Clean cancellation with optional cancellation handlers
- ✅ **Dynamic Interval Adjustment** - Change timer intervals on-the-fly
- ✅ **Thread Safety** - Actor-based design ensures thread-safe operation
- ✅ **Lightweight** - Zero dependencies, minimal footprint

## Requirements

- Swift 5.9+ / Swift 6.0
- iOS 13.0+
- macOS 10.15+
- tvOS 13.0+
- watchOS 6.0+
- visionOS 1.0+

## Installation

### Swift Package Manager

Add AsyncTimer to your project using Swift Package Manager by adding it to your `Package.swift` file's dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/AsyncTimer.git", from: "0.0.1")
]
```

Or add it directly in Xcode:
1. Go to **File** > **Add Packages...**
2. Enter the repository URL: `https://github.com/yourusername/AsyncTimer.git`
3. Select the version or branch you want to use

## Usage

### Basic Examples

#### One-time Timer

```swift
import AsyncTimer

func example() async {
    let timer = AsyncTimer(
        interval: 1.0,  // 1 second
        repeating: false,
        handler: {
            print("Timer fired once!")
        }
    )
    
    await timer.start()
    // Timer will fire after 1 second and then stop automatically
}
```

#### Repeating Timer

```swift
import AsyncTimer

func example() async {
    let timer = AsyncTimer(
        interval: 0.5,  // 0.5 seconds
        repeating: true,
        handler: {
            print("Timer fired repeatedly!")
        }
    )
    
    await timer.start()
    
    // Let the timer run for 3 seconds
    try? await Task.sleep(for: .seconds(3))
    
    // Stop the timer
    await timer.stop()
}
```

#### Using Cancellation Handler

```swift
import AsyncTimer

func example() async {
    let timer = AsyncTimer(
        interval: 1.0,
        repeating: true,
        handler: {
            print("Timer fired!")
        },
        cancelHandler: {
            print("Timer was cancelled!")
        }
    )
    
    await timer.start()
    
    // Later, when you want to stop the timer
    await timer.stop()  // This will trigger the cancelHandler
}
```

#### Changing Timer Interval

```swift
import AsyncTimer

func example() async {
    let timer = AsyncTimer(
        interval: 1.0,
        repeating: true,
        handler: {
            print("Timer fired!")
        }
    )
    
    await timer.start()
    
    // Run at 1-second intervals for a while
    try? await Task.sleep(for: .seconds(3))
    
    // Change to 0.5-second intervals
    await timer.setInterval(0.5)
    
    // Run at new interval for a while
    try? await Task.sleep(for: .seconds(3))
    
    // Stop the timer
    await timer.stop()
}
```

#### Setting Task Priority

```swift
import AsyncTimer

func example() async {
    let highPriorityTimer = AsyncTimer(
        interval: 1.0,
        priority: .high,
        repeating: true,
        handler: {
            print("High priority timer fired!")
        }
    )
    
    let lowPriorityTimer = AsyncTimer(
        interval: 1.0,
        priority: .low,
        repeating: true,
        handler: {
            print("Low priority timer fired!")
        }
    )
    
    await highPriorityTimer.start()
    await lowPriorityTimer.start()
    
    // High priority timer will generally execute before low priority timer
}
```

## API Reference

### AsyncTimer

```swift
public final actor AsyncTimer
```

A simple repeating timer that runs a task at a specified interval.

#### Initialization

```swift
public init(
    interval: TimeInterval,
    priority: TaskPriority = .medium,
    repeating: Bool = false,
    firesImmediately: Bool = true,
    handler: @escaping RepeatHandler,
    cancelHandler: CancelHandler? = nil
)
```

- **interval**: The interval at which the timer fires (in seconds)
- **priority**: The priority of the task (default: `.medium`)
- **repeating**: Whether the timer should repeat (default: `false`)
- **firesImmediately**: Whether the timer should fire immediately upon starting (default: `true`, only effective when `repeating` is `true`)
- **handler**: The handler that is called when the timer fires
- **cancelHandler**: The handler that is called when the timer is cancelled (optional)

#### Properties

```swift
public var isRunning: Bool
```

Whether the timer is currently running.

#### Methods

```swift
public func start()
```

Starts the timer. If the timer is already running, it will be stopped and restarted.

```swift
public func stop()
```

Stops the timer.

```swift
public func restart()
```

Restarts the timer (equivalent to calling `stop()` followed by `start()`).

```swift
public func setInterval(_ newInterval: TimeInterval)
```

Modifies the interval of the timer. This will also restart the timer if it's currently running.

```swift
public static func sleep(_ interval: TimeInterval) async throws
```

Utility method to sleep for the specified interval.

## Advanced Usage

### Handling Concurrency

Since `AsyncTimer` is implemented as an actor, all its methods are automatically thread-safe. You can safely call methods from different tasks without worrying about race conditions.

```swift
let timer = AsyncTimer(interval: 1.0, repeating: true) {
    print("Timer fired!")
}

// These can be called from different tasks safely
Task {
    await timer.start()
}

Task {
    try await Task.sleep(for: .seconds(5))
    await timer.stop()
}
```

## Contributing

Contributions are welcome! If you find a bug or have a feature request, please open an issue. If you'd like to contribute code, please fork the repository and submit a pull request.

## License

AsyncTimer is available under the MIT license. See the LICENSE file for more info.
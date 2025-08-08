# AsyncTimer

[![Swift](https://img.shields.io/badge/Swift-5.10%2B-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%20|%20macOS%20|%20tvOS%20|%20watchOS%20|%20visionOS-blue.svg)](https://developer.apple.com)
[![Swift Package Manager](https://img.shields.io/badge/Swift_Package_Manager-compatible-brightgreen.svg)](https://swift.org/package-manager)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A lightweight, modern Swift async/await timer/debounce/throttle implementation for Apple platforms.

## Features

- ✅ **Swift Concurrency** - Built with Swift's modern concurrency model using async/await and actors
- ✅ **Thread Safety** - Actor-based design ensures thread-safe operation
- ✅ **Lightweight** - Zero dependencies, minimal footprint
- ✅ **Timer Utilities** - Built-in `AsyncTimer` with support for one-time and repeating timers with configurable intervals
- ✅ **Debounce Utilities** - Built-in `AsyncDebouncer` with configurable debounce time
- ✅ **Throttle Utilities** - Built-in `AsyncThrottler` with leading/trailing and drift/anti-drift cadence

## Requirements

- Swift 5.10+ / Swift 6.0
- iOS 13.0+
- macOS 10.15+
- macCatalyst 13.0+
- tvOS 13.0+
- watchOS 6.0+
- visionOS 1.0+

## Installation

### Swift Package Manager

Add AsyncTimer to your project using Swift Package Manager by adding it to your `Package.swift` file's dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/codingiran/AsyncTimer.git", from: "0.0.7")
]
```

Or add it directly in Xcode:

1. Go to **File** > **Add Packages...**
2. Enter the repository URL: `https://github.com/codingiran/AsyncTimer.git`
3. Select the version or branch you want to use

## Usage (Quick Start)

### AsyncTimer

```swift
import AsyncTimer

// One-time
let once = AsyncTimer(interval: .seconds(1), repeating: false) {
    print("fire once")
}
await once.start()

// Repeating (fire immediately on start)
let repeating = AsyncTimer(interval: .seconds(0.5), repeating: true, firesImmediately: true) {
    print("tick")
}
await repeating.start()
// ... later
await repeating.stop()
```

### AsyncThrottler

```swift
import AsyncTimer

let throttler = AsyncThrottler(
    throttleTime: .seconds(0.2),
    behavior: .trailingOnly, // .leadingOnly / .leadingAndTrailing
    cadence: .antiDrift      // .drift for rolling windows
)

// High-frequency calls → at most one execution per window
await throttler.call { print("work") }
```

### AsyncDebouncer

```swift
import AsyncTimer

let debouncer = AsyncDebouncer(debounceTime: .seconds(0.2))
await debouncer.call { print("fire after quiet period") }
```

## Contributing

Contributions are welcome! If you find a bug or have a feature request, please open an issue. If you'd like to contribute code, please fork the repository and submit a pull request.

## License

AsyncTimer is available under the MIT license. See the LICENSE file for more info.

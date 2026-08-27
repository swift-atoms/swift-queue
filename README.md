# Queue

![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)
[![CI](https://github.com/swift-molecules/swift-queue/actions/workflows/ci.yml/badge.svg)](https://github.com/swift-molecules/swift-queue/actions/workflows/ci.yml)

`Queue<S>` — a FIFO queue that is generic over its storage **column**. Like the array family, the queue writes its element surface once against a column seam and lets the column decide ownership and capacity: a move-only ring column gives a zero-cost move-only queue, a `Shared` ring column gives copy-on-write value semantics, and a bounded ring column gives a fixed-capacity queue. Copyability flows from the column, not from per-queue machinery.

The column is a **ring** (`Buffer.Ring`): logical slot 0 is the front, so `dequeue` advances the head in O(1) and `enqueue` appends at the back — no element shifting. The element-generic surface (`enqueue`, `dequeue`, `peek`, `drain`, the gated subscript) lives once for every column; only construction, growth, and capacity operations are specialized per column. The fixed-capacity story lives entirely in the bounded ring column rather than in a separate queue type.

---

## Key Features

- **O(1) FIFO** — front-anchored ring storage; `dequeue` advances the head and `enqueue` appends the back with no shifting.
- **Ownership from the column** — move-only by default; opt into copy-on-write value semantics by choosing a `Shared` column.
- **Fixed-capacity via the column** — a bounded ring column gives a throwing, allocation-free queue; no separate bounded queue type.
- **Move-only elements** — `~Copyable` elements are enqueued and dequeued by ownership transfer.

---

## Quick Start

```swift
import Queue
import Column

var queue = Queue<Column.Ring<Int>>()    // move-only, over a growable ring column
queue.enqueue(1)
queue.enqueue(2)
let first = queue.dequeue()              // Optional(1) — O(1) head advance
queue.peek { $0 }                        // Optional(2) — borrows the front in place
```

---

## Installation

Add the dependency to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/swift-molecules/swift-queue.git", branch: "main")
]
```

Add the product to your target:

```swift
.target(
    name: "App",
    dependencies: [
        .product(name: "Queue", package: "swift-queue")
    ]
)
```

The package is pre-1.0 — depend on `branch: "main"` until `0.1.0` is tagged. Requires Swift 6.3 and macOS 26 / iOS 26 / tvOS 26 / watchOS 26 / visionOS 26 (or the corresponding Linux / Windows toolchain).

---

## Architecture

| Product | Contents | When to import |
|---------|----------|----------------|
| `Queue` | Umbrella — `Queue<S>` and its conformances | Most consumers |
| `Queue Primitive` | `Queue<S>` — the FIFO queue over a ring column | Naming the type directly |

---

## Platform Support

| Platform         | CI  | Status       |
|------------------|-----|--------------|
| macOS 26         | Yes | Full support |
| Linux            | Yes | Full support |
| Windows          | Yes | Full support |
| iOS/tvOS/watchOS | —   | Supported    |
| Swift Embedded   | —   | Pending (nightly-toolchain follow-up) |

---

## Related Packages

- [`swift-buffer-ring`](https://github.com/swift-molecules/swift-buffer-ring) — the front-anchored ring column the queue is built over.
- [`swift-array`](https://github.com/swift-molecules/swift-array) — the random-access sibling that shares the column-generic design.
- [`swift-deque`](https://github.com/swift-molecules/swift-deque) — the double-ended generalization.

---

## Community

<!-- BEGIN: discussion -->
<!-- END: discussion -->

## License

Apache 2.0. See [LICENSE.md](LICENSE.md).

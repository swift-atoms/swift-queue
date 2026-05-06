// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-primitives open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-primitives project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

public import Queue_Primitives_Core

extension Queue.Linked.Fixed where Element: ~Copyable {
    /// Constructs a heap-allocated bounded linked-FIFO queue from a result-builder closure.
    public init(
        capacity: Index<Element>.Count,
        @Queue<Element>.Linked.Builder _ builder: () -> Queue<Element>.Linked
    ) throws(Error) {
        var fixed = try Queue<Element>.Linked.Fixed(capacity: capacity)
        var dynamic = builder()
        while let elem = dynamic.dequeue() {
            try fixed.enqueue(consume elem)
        }
        self = fixed
    }
}

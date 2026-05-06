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

extension Queue.Linked.Small where Element: Copyable {
    /// Constructs a SmallVec linked-FIFO queue from a result-builder closure.
    ///
    /// Element constraint: Copyable. Queue.Linked.Small's enqueue is
    /// declared on `where Element: Copyable` only; ~Copyable Element
    /// support is a separate ecosystem extension.
    public init(
        @Queue<Element>.Linked.Builder _ builder: () -> Queue<Element>.Linked
    ) throws(Error) {
        var dynamic = builder()
        self.init()
        while let elem = dynamic.dequeue() {
            try self.enqueue(elem)
        }
    }
}

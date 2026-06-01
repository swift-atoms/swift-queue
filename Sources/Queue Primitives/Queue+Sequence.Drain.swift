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

public import Queue_Primitive
public import Sequence_Primitives

// MARK: - Sequence.Drain.Protocol (~Copyable)
//
// The cold drain conformance is isolated in the ops module per [MOD-004]/[MOD-036] (it brings the
// `Sequence_Primitives` import). Its body uses only the public `~Copyable` `dequeue()` surface.

extension Queue: Sequence.Drain.`Protocol` where Element: ~Copyable {
    /// Drains all elements in FIFO order, passing each to the closure with ownership.
    ///
    /// After this method returns, the queue is empty but still usable.
    ///
    /// - Parameter body: A closure that receives each drained element with ownership.
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public mutating func drain(_ body: (consuming Element) -> Void) {
        while let element = dequeue() {
            body(element)
        }
    }
}

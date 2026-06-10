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

public import Index_Primitives

extension Queue where S: ~Copyable {
    /// Type-safe index for queue elements — typed by the COLUMN's element, preventing
    /// cross-collection index confusion.
    ///
    /// ## Position Semantics
    ///
    /// Position 0 is the FRONT of the queue (next to be dequeued); the last position is
    /// the back (most recently enqueued). Positions RE-ANCHOR after a dequeue: the old
    /// position 1 becomes position 0 (the ring discipline's front-anchored indexing).
    public typealias Index = Index_Primitives.Index<S.Element>
}

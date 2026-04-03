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

extension Queue.DoubleEnded where Element: ~Copyable {
    /// Errors that can occur during double-ended queue operations.
    ///
    /// ## Cases
    ///
    /// - ``Queue/DoubleEnded/Error/empty``: The deque is empty and the operation requires elements.
    /// - ``Queue/DoubleEnded/Error/invalidCapacity``: The requested capacity is invalid (negative).
    public enum Error: Swift.Error, Sendable, Equatable {
        /// The deque is empty and the operation requires elements.
        case empty

        /// The requested capacity is invalid (negative).
        case invalidCapacity
    }
}

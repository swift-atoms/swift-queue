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

extension Queue.Linked.Fixed where Element: ~Copyable {
    /// Errors that can occur during bounded linked queue operations.
    ///
    /// ## Cases
    ///
    /// - ``Queue/Linked/Fixed/Error/empty``: The queue is empty and the operation requires elements.
    /// - ``Queue/Linked/Fixed/Error/invalidCapacity``: The requested capacity is invalid (negative).
    /// - ``Queue/Linked/Fixed/Error/overflow``: The queue is full and cannot accept more elements.
    public enum Error: Swift.Error, Sendable, Equatable {
        /// The queue is empty and the operation requires elements.
        case empty

        /// The requested capacity is invalid (negative).
        case invalidCapacity

        /// The queue is full and cannot accept more elements.
        case overflow
    }
}

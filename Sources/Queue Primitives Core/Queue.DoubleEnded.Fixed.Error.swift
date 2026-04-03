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

extension Queue.DoubleEnded.Fixed where Element: ~Copyable {
    /// Errors that can occur during fixed-capacity double-ended queue operations.
    ///
    /// ## Cases
    ///
    /// - ``Queue/DoubleEnded/Fixed/Error/invalidCapacity``: The requested capacity is invalid (negative).
    /// - ``Queue/DoubleEnded/Fixed/Error/overflow``: The queue is full and cannot accept more elements.
    public enum Error: Swift.Error, Sendable, Equatable {
        /// The requested capacity is invalid (negative).
        case invalidCapacity

        /// The queue is full and cannot accept more elements.
        case overflow
    }
}

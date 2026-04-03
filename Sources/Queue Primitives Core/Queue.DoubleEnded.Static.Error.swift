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

extension Queue.DoubleEnded.Static {
    /// Errors that can occur during static double-ended queue operations.
    ///
    /// ## Cases
    ///
    /// - ``Queue/DoubleEnded/Static/Error/overflow``: The queue is full and cannot accept more elements.
    public enum Error: Swift.Error, Sendable, Equatable {
        /// The queue is full and cannot accept more elements.
        case overflow
    }
}

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

extension Queue.Static where Element: ~Copyable {
    /// Errors that can occur during static queue operations.
    ///
    /// For `Queue.Static`, only `overflow` can occur. The capacity is
    /// fixed at compile time, so `invalidCapacity` is impossible.
    ///
    /// ## Cases
    ///
    /// - ``Queue/Static/Error/overflow``: The queue is full and cannot accept more elements.
    public enum Error: Swift.Error, Sendable, Equatable {
        /// The queue is full and cannot accept more elements.
        case overflow
    }
}

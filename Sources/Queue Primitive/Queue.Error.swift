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

extension Queue where Element: ~Copyable {
    /// Errors that can occur during unbounded queue operations.
    ///
    /// For the unbounded `Queue`, only `invalidCapacity` can occur
    /// (when reserving negative capacity). The queue grows automatically,
    /// so overflow is impossible.
    ///
    /// ## Cases
    ///
    /// - ``Queue/Error/invalidCapacity``: The requested capacity is invalid (negative).
    public enum Error: Swift.Error, Sendable, Equatable {
        /// The requested capacity is invalid (negative).
        case invalidCapacity
    }
}

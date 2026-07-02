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

extension __Queue where S: ~Copyable {
    /// Errors thrown by queue operations.
    ///
    /// Only the BOUNDED columns can overflow (`full` — fixed-capacity semantics,
    /// carried by the column); growable columns grow instead.
    public enum Error: Swift.Error, Sendable, Equatable {
        /// The fixed-capacity column is full; the enqueued element was rejected
        /// (and, being unreturned, destroyed — snapshot a copy first if it must
        /// survive a full queue).
        case full
    }
}

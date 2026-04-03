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

extension Queue.Linked.Small where Element: Copyable {
    /// Errors that can occur during small linked queue operations.
    ///
    /// ## Cases
    ///
    /// - ``Queue/Linked/Small/Error/empty``: The queue is empty and the operation requires elements.
    public enum Error: Swift.Error, Sendable, Equatable {
        /// The queue is empty and the operation requires elements.
        case empty
    }
}

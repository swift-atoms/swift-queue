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

// MARK: - Hoisted Error Types (Module Level)
//
// Swift does not allow nested types inside generic types to be easily accessed.
// These error types are hoisted to module level and exposed via typealiases to
// provide the expected Nest.Name API (Queue.Error, Queue.Bounded.Error, etc.).
//
// This is a documented exception per [API-EXC-001] due to Swift language
// limitations with generic nested types.
//
// Use the typealias forms in your code:
// - Queue<Element>.Error
// - Queue<Element>.Bounded.Error
// - Queue<Element>.Inline.Error

/// Hoisted implementation of ``Queue/Error``.
///
/// - Note: Use ``Queue/Error`` in your code, not this type directly.
public enum __QueueError: Swift.Error, Sendable, Equatable {
    /// The requested capacity is invalid (negative).
    case invalidCapacity
}

/// Hoisted implementation of ``Queue/Bounded/Error``.
///
/// - Note: Use ``Queue/Bounded/Error`` in your code, not this type directly.
public enum __QueueBoundedError: Swift.Error, Sendable, Equatable {
    /// The requested capacity is invalid (negative).
    case invalidCapacity

    /// The queue is full and cannot accept more elements.
    case overflow
}

/// Hoisted implementation of ``Queue/Inline/Error``.
///
/// - Note: Use ``Queue/Inline/Error`` in your code, not this type directly.
public enum __QueueInlineError: Swift.Error, Sendable, Equatable {
    /// The queue is full and cannot accept more elements.
    case overflow
}

// MARK: - Typealiases (Nest.Name API)
//
// IMPORTANT: Extensions MUST include `where Element: ~Copyable` to prevent
// implicit Copyable constraint. This is a documented Swift compiler limitation.

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
    public typealias Error = __QueueError
}

extension Queue.Bounded where Element: ~Copyable {
    /// Errors that can occur during bounded queue operations.
    ///
    /// ## Cases
    ///
    /// - ``Queue/Bounded/Error/invalidCapacity``: The requested capacity is invalid (negative).
    /// - ``Queue/Bounded/Error/overflow``: The queue is full and cannot accept more elements.
    public typealias Error = __QueueBoundedError
}

extension Queue.Inline where Element: ~Copyable {
    /// Errors that can occur during inline queue operations.
    ///
    /// For `Queue.Inline`, only `overflow` can occur. The capacity is
    /// fixed at compile time, so `invalidCapacity` is impossible.
    ///
    /// ## Cases
    ///
    /// - ``Queue/Inline/Error/overflow``: The queue is full and cannot accept more elements.
    public typealias Error = __QueueInlineError
}

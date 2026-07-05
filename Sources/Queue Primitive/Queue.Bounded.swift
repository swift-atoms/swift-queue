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

public import Store_Protocol_Primitives

// MARK: - Queue<E>.Bounded — the CAPACITY variant ([DS-028])

extension __Queue where S: Store.Direct, S: ~Copyable {

    /// A fixed-capacity FIFO queue: the bounded ring column (rejects on overflow
    /// with typed throws at the family surface — the dissolved former
    /// `Queue.Fixed`).
    ///
    /// This is a capacity-axis variant alias ([DS-028] law 2): `Queue<Element>.Bounded`
    /// maps the canonical carrier's column through the **capacity twin** —
    /// `__Queue<S.Bounded>` — so it is **column-PRESERVING**: for the default ring column
    /// `S.Bounded` is `Buffer.Ring.Bounded` (the ring's own bounded twin), and for any
    /// other direct column it is that column's bounded twin, never a Heap-hardcoded rebuild.
    /// A cross-axis chain from a non-heap column therefore keeps its axis instead of silently
    /// resetting it. `Element` is inherited from the member it is named on. Enqueue on the
    /// bounded column throws `Error.full` (the decreed `throws(Overflow)` op form under the
    /// D4.1 variant test — a form difference, not a sibling).
    ///
    /// The `where S: __ColumnDirect` fence ([DS-028] law 1) is what makes the twin available;
    /// the alias body is generic over `S.Bounded`, so it names no concrete bounded type
    /// here (consumers resolving `Queue<E>.Bounded` see the concrete `Buffer.Ring.Bounded`
    /// through the carrier's own `Buffer Ring Bounded Primitive` re-export). Ring op
    /// generalization stays wave W3; this leg re-expresses the ALIAS only.
    public typealias Bounded = __Queue<S.Bounded>
}

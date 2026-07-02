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

public import Buffer_Primitive
public import Buffer_Ring_Bounded_Primitive
public import Storage_Contiguous_Primitives
public import Store_Protocol_Primitives
public import Memory_Heap_Primitives
public import Memory_Allocator_Primitive

// MARK: - Queue<E>.Bounded — the CAPACITY variant ([DS-028])

extension __Queue where S: Store.`Protocol` & ~Copyable {

    /// A fixed-capacity FIFO queue: the bounded ring column (rejects on overflow
    /// with typed throws at the family surface — the dissolved former
    /// `Queue.Fixed`).
    ///
    /// This is a capacity-axis variant alias ([DS-028]): `Queue<Element>.Bounded`
    /// re-parameterizes the canonical carrier onto the bounded ring discipline,
    /// inheriting `Element` from the member it is named on. Enqueue on the bounded
    /// column throws `Error.full` (the decreed `throws(Overflow)` op form under
    /// the D4.1 variant test — a form difference, not a sibling).
    ///
    /// The alias reconstructs the bounded column from `S.Element`; because no
    /// `Shared` front door yet chains ahead of it, the simple reconstruct form is
    /// order-insensitive here. The capacity-twin transformer form (D4.2 law 2)
    /// lands with the buffer-tier `BoundedTwin` associated type (wave W3), needed
    /// only once an ownership front door exists to chain with.
    public typealias Bounded =
        __Queue<Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<S.Element>>.Ring.Bounded>
}

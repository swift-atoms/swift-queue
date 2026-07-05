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

import Queue_Primitives
import Buffer_Primitive
import Buffer_Ring_Primitive
import Buffer_Ring_Bounded_Primitive
import Storage_Contiguous_Primitives
import Memory_Heap_Primitives
import Memory_Allocator_Primitive
import Ownership_Shared_Primitive
import Index_Primitives
import Tagged_Primitives_Standard_Library_Integration
import Ordinal_Primitives
import Ordinal_Primitives_Standard_Library_Integration
import Cardinal_Primitives

// The four ratified ring columns, spelled exactly as the package's own test
// suite spells them (queue tests' column prelude).

typealias HeapStorage<E: ~Copyable> =
    Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>

typealias GrowableRing<E: ~Copyable> = Buffer<HeapStorage<E>>.Ring

typealias BoundedRing<E: ~Copyable> = Buffer<HeapStorage<E>>.Ring.Bounded

typealias MoveQueue<E: ~Copyable> = Queue<GrowableRing<E>>

typealias CoWQueue<E: ~Copyable> = Queue<Ownership.Shared<E, GrowableRing<E>>>

typealias FixedQueue<E: ~Copyable> = Queue<BoundedRing<E>>

extension Bench {
    /// Typed count from a runtime size via the non-throwing `UInt` lane.
    static func count<E>(_ n: Int) -> Index_Primitives.Index<E>.Count {
        Index_Primitives.Index<E>.Count(Cardinal(UInt(n)))
    }
}

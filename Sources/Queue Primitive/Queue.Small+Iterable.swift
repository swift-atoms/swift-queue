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

public import Buffer_Ring_Primitives
public import Storage_Small_Primitives
public import Storage_Primitive
public import Buffer_Ring_Primitive
public import Buffer_Ring_Primitives
public import Memory_Heap_Primitives
public import Storage_Contiguous_Primitives
public import Buffer_Ring_Small_Primitive
public import Buffer_Ring_Small_Primitives
public import Iterable
public import Iterator_Primitive
public import Iterator_Chunk_Primitives

// MARK: - Iterable (multipass, borrowing) — via materialising adapter
//
// `Queue.Small` is unconditionally `~Copyable`: its backing `Buffer.Ring.Small` hybrid inline
// `@_rawLayout` / heap ring storage cannot be copied, so the borrowing `Iterable.makeIterator()`
// cannot build the owning consuming `Scalar` (used by `Sequenceable`). Per-backing divergence from
// the Dynamic exemplar (where `_buffer` is CoW-copyable): the `Iterable` face delegates to the
// small ring's OWN borrow-backed `Iterable` witness — the borrow-backed scalar walker
// `Buffer.Ring.Small.Walk` wrapped in `Iterator.Materializing`. The queue does NOT conform
// `Span.Protocol` (no element span — the ring wraps).
//
// `@_implements` splits the unified `Iterator` associated type: `Iterable.Iterator` binds the
// materialising bulk iterator here; `Sequenceable.Iterator` binds the scalar
// (Queue.Small+Sequenceable.swift).

// DEFERRED (Cleave-3 #12a, iterate-after — principal-authorized): the multipass `Iterable`
// face over a `Storage.Small`-backed ring needs a `Buffer.Ring.Walk` (borrow-backed raw-pointer
// multipass walker) on the GENERIC `Buffer.Ring`. Porting the variant's `Buffer.Ring.Small.Walk`
// to the base buffer is tangled: the base ring already vends a single Iterable conformance via
// the span-chunk `Segments` (which stays `S: Copyable` — it yields the `~Escapable` span across
// calls), so a second `~Copyable` Walk-based Iterable conformance would collide, and the generic
// base-pointer extraction the Walk needs is not on the neutral seam. Single-pass `Sequenceable`
// (the consuming `Scalar`) IS generalized to `Storage.Small` (Queue.Small+Sequenceable.swift) and
// covers iteration; the multipass face is deferred to the growth-genericity follow-up.
//
// extension Queue.Small: Iterable where Element: Copyable { … via Buffer.Ring.Walk … }

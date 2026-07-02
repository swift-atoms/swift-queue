// exports.swift
// Queue Primitive declares the hoisted carrier `struct __Queue<S: ~Copyable>` (the
// FIFO ADT over an explicit ring COLUMN, [DS-025]) + the front doors `Queue<E>`
// (canonical) and `Queue<E>.Bounded` ([DS-028]) + `Queue.Index`/`Queue.Error` +
// `take()` + the pinned column constructors.
// Per the exports-narrowing ruling (audit #9, 2026-06-10), nothing is re-exported:
// consumers SPELL their column by importing the column-vocabulary modules explicitly
// (Buffer/Storage/Memory/Shared/Index).

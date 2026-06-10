// exports.swift
// Queue Primitive declares `struct Queue<S>` (the FIFO ADT over an explicit ring
// COLUMN) + `Queue.Index`/`Queue.Error` + `take()` + the pinned column constructors.
// Per the exports-narrowing ruling (audit #9, 2026-06-10), nothing is re-exported:
// consumers SPELL their column by importing the column-vocabulary modules explicitly
// (Buffer/Storage/Memory/Shared/Index).

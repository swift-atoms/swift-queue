---
name: queue-primitives
description: |
  FIFO queue collection primitives with ~Copyable element support.
  ALWAYS apply when working with queue data structures.

layer: implementation

requires:
  - primitives
  - memory

applies_to:
  - swift
  - swift-primitives
  - swift-queue-primitives
---

# Queue Primitives

FIFO queue collection with first-class ~Copyable support.

---

## Core Design Decisions

### [QUE-001] Storage Variants

| Variant | Storage | Use Case |
|---------|---------|----------|
| `Queue.Inline<N>` | Stack-allocated | Small, fixed capacity |
| `Queue.Fixed` | Heap, circular | Known upper bound |
| `Queue.Unbounded` | Heap, growable | Dynamic size |

### [QUE-002] Circular Buffer Implementation

**Statement**: Bounded queues MUST use circular buffer for O(1) operations.

### [QUE-003] ~Copyable Elements

**Statement**: All queue variants MUST support `~Copyable` elements.

---

## Key Operations

| Operation | Complexity | Ownership |
|-----------|------------|-----------|
| `enqueue(_:)` | O(1) amortized | consuming |
| `dequeue()` | O(1) | consuming |
| `peek` | O(1) | borrowing |

---

## Cross-References

Full analysis: `Research/Collection Primitives Architecture.md`

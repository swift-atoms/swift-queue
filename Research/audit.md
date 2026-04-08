# Audit: swift-queue-primitives

## Implementation — 2026-03-31

### Scope

- **Target**: Queue DoubleEnded Primitives
- **Skill**: implementation — [IMPL-065], [IMPL-INTENT]
- **Files**: Queue.DoubleEnded.Accessor.swift

### Findings

| # | Severity | Rule | Location | Finding | Status |
|---|----------|------|----------|---------|--------|
| 1 | MEDIUM | [IMPL-065] | Queue.DoubleEnded.Accessor.swift:117 | `func peek<R: ~Copyable>(_ body: (borrowing Element) -> R) -> R?` uses closure pattern for ~Copyable element peek. Property-based `var peek: Ownership.Borrow<Element>?` would be more ergonomic per [IMPL-INTENT] but is blocked by ~Escapable lifetime scoping: Property.View is the terminal ~Escapable layer — returning `Ownership.Borrow` (also ~Escapable) from a View method creates a scope nesting violation. Same issue at back peek (line 209). | DEFERRED — blocked by nested ~Escapable coroutine scope limitation. Revisit when SE-0519 `Borrow<T>` ships (uses `Builtin.Borrow`, avoids `UnsafePointer` lifetime chain) or when `yielding borrow` (SE-0474) changes scope semantics. Research: `swift-institute/Research/noncopyable-peek-escapable.md`. Experiment: `swift-primitives/Experiments/noncopyable-peek-escapable/`. |

### Summary

1 finding: 0 critical, 0 high, 1 medium, 0 low.
Closure-based peek is correct and production-proven. The property-based alternative (`Ownership.Borrow<Element>?`) was experimentally confirmed to work in isolation (7/7 variants CONFIRMED) but cannot be wired through the Property.View architecture due to ~Escapable scope nesting. The closure pattern remains the right design until Swift's lifetime system can compose ~Escapable values across nested coroutine scopes.

## Legacy — Consolidated 2026-04-08

### From: swift-institute/Research/audit-primitives.md (2026-04-03)

**Pre-publication dependency-tree audit — P0/P1/P2 checks**

#### P1: Multi-Type File [API-IMPL-005]

**File**: `Sources/Queue Primitives Core/Queue.Error.swift` (11 types, 177 lines)

| Line | Type |
|------|------|
| 29 | `__QueueError` |
| 37 | `__QueueBoundedError` |
| 48 | `__QueueStaticError` |
| 56 | `__QueueLinkedError` |
| 67 | `__QueueLinkedBoundedError` |
| 81 | `__QueueLinkedInlineError` |
| 92 | `__QueueLinkedSmallError` |
| 100 | `__QueueDoubleEndedError` |
| 111 | `__QueueDoubleEndedFixedError` |
| 122 | `__QueueDoubleEndedStaticError` |
| 130 | `__QueueDoubleEndedSmallError` |

**Assessment**: `__`-prefixed internal error enums hoisted to module scope for typed throws. Grouping is arguably justified: each file contains related error types for variants of the same data structure sharing documentation context. Splitting to one file per `__`-prefixed error enum would create 11 additional files with low individual value.

**Recommendation**: Accept as-is or split only the largest file. The `__` prefix already signals implementation infrastructure, not public API surface.

---

### From: swift-institute/Research/audits/implementation-naming-2026-03-20/swift-queue-primitives.md (2026-03-20)

**Implementation + naming audit**

HIGH=16, MEDIUM=12, LOW=14, INFO=14
Finding IDs: IMPL-002, IMPL-010, IMPL-021, IMPL-033, PATTERN-017, PATTERN-018, PATTERN-021, PATTERN-022, Q-001, Q-002, Q-003, Q-004, Q-005, Q-006, Q-007 (+17 more)

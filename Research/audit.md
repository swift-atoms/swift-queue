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

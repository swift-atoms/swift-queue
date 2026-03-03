# Queue Primitives Insights

<!--
---
title: Queue Primitives Insights
version: 1.0.0
last_updated: 2026-01-22
applies_to: [swift-queue-primitives]
normative: false
---
-->
Design decisions, implementation patterns, and lessons learned specific to this package.

## Overview

This document captures insights that emerged during development of swift-queue-primitives. These are not API requirements—they are recorded decisions and patterns that inform future work on this package.

**Document type**: Non-normative (recorded decisions, not requirements).

**Consolidation source**: Reflection entries tagged with `[Package: swift-queue-primitives]`.

---

## The Nested Type Escape Hatch for ~Copyable Propagation

**Date**: 2026-01-20

**Context**: Fixing Queue.Linked to work with ~Copyable elements after discovering that external generic type references fail to propagate the constraint suppression.

Swift's `~Copyable` constraint suppression has a propagation boundary that wasn't documented in official sources. When a generic type parameter has its Copyable requirement suppressed (via `~Copyable`), that suppression propagates correctly to:
- Nested types declared **inside** the same type body
- Extensions on the same type
- Local variables and parameters

But suppression **fails to propagate** to:
- Cross-module generic type instantiations (e.g., `List<Element>.Linked<1>`)
- Module-level generic types accessed with the outer type's generic parameter
- Generic typealiases that reference external types

The propagation boundary isn't about module boundaries per se—it's about **lexical nesting**. The generic parameter must be in the same lexical scope as the types that use it. External generic types, even in the same module, create a new scope where the constraint suppression doesn't reach.

### Why Module-Level Types Also Fail

The first attempted workaround was duplicating storage types at module level:

```swift
@usableFromInline
final class __QueueLinkedStorage<Element: ~Copyable>: ManagedBuffer<...> { ... }
```

This failed with the same error. The `Element` in `Queue.Linked` and the `Element` in `__QueueLinkedStorage<Element>` are **different generic parameters** that happen to share a name. The compiler sees them as unrelated. The `~Copyable` suppression on `Queue<Element>` doesn't automatically transfer to `__QueueLinkedStorage<Element>` just because you pass `Element` as a type argument.

This is conceptually similar to how type inference works—generics are resolved at the call site, not at the definition site. The definition of `__QueueLinkedStorage` requires `Element: Copyable` (implicitly), and that requirement must be satisfied when you write `__QueueLinkedStorage<Element>`.

### The Working Pattern

The only pattern that works is nesting the storage types **inside** the type that has the `~Copyable` parameter:

```swift
public struct Queue<Element: ~Copyable>: ~Copyable {
    public struct Linked: ~Copyable {
        struct Header { ... }
        struct Node: ~Copyable {
            var element: Element  // This Element IS the outer Element
        }
        final class Storage: ManagedBuffer<Header, Node> { ... }

        var _storage: Storage  // Works because Storage is nested
    }
}
```

When `Node` references `Element`, it's the **same** `Element` from the enclosing `Queue` type, with its constraint suppression intact. The nesting creates lexical scope inheritance for generic parameters.

### Implications for Library Design

This has significant implications for how move-only container types should be structured:

1. **Storage cannot be shared across container types** via module-level abstractions when supporting `~Copyable`. Each container needs its own nested storage hierarchy.

2. **Code duplication is sometimes necessary**. The Queue.Linked storage is essentially a copy of List.Linked storage, nested differently. This is a workaround for a compiler limitation, not a design choice.

3. **Copyable-constrained variants can still share storage**. `Queue.Linked.Inline` and `Queue.Linked.Small` use `List<Element>.Linked<1>.Inline` because they're constrained to `where Element: Copyable`. The bug only manifests when Element is `~Copyable`.

4. **Document the workaround explicitly**. The code includes prominent comments marking this as temporary, with tracking references for when the compiler is fixed.

### Experiment Findings

What made this investigation interesting was that standalone experiments in isolation **passed**. A minimal reproduction:

```swift
// In separate experiment package
import List_Primitives

struct TestQueue<Element: ~Copyable>: ~Copyable {
    var _storage: List<Element>.Linked<1>  // WORKS in isolation!
}
```

This compiles. But the **same pattern** inside the full Queue implementation fails. The difference: Queue has other nested types (Bounded, Inline, Small) and a Storage class. The interaction between multiple nested types in a non-empty struct triggers the bug.

This reinforces the value of the [EXP-004a] Incremental Construction methodology—test patterns in isolation, then in increasing complexity, to find exactly where behavior changes.

**Applies to**: `Queue.Linked` storage implementation and any future container types supporting `~Copyable` elements.

---

## Related

- Queue

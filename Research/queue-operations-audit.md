# Queue Operations Audit

<!--
---
version: 1.0.0
last_updated: 2026-02-16
status: RECOMMENDATION
tier: 1
---
-->

## Context

Proactive audit of swift-queue-primitives to inventory all public operations and compare against canonical Queue ADT operations.

**Trigger**: [RES-012] Discovery -- proactive operations audit across 13 data structure packages.
**Scope**: Package-specific (swift-queue-primitives).

## Question

Does swift-queue-primitives provide the canonical operations expected of the Queue ADT (FIFO and Double-Ended)?

## Canonical Operations (ADT Reference)

### FIFO Queue

| Operation | Expected Complexity | Description |
|-----------|-------------------|-------------|
| enqueue(x) | O(1) amortized | Add to back |
| dequeue() | O(1) | Remove from front |
| front()/peek() | O(1) | View front element |
| is_empty | O(1) | Empty check |
| size/count | O(1) | Number of elements |

### Double-Ended Queue (Deque)

| Operation | Expected Complexity | Description |
|-----------|-------------------|-------------|
| push_front(x) | O(1) | Add to front |
| push_back(x) | O(1) | Add to back |
| pop_front() | O(1) | Remove from front |
| pop_back() | O(1) | Remove from back |
| front()/peek_front() | O(1) | View front |
| back()/peek_back() | O(1) | View back |

---

## Current Operations Inventory

### Variant: Queue (Dynamic)

**Type**: `Queue<Element: ~Copyable>: ~Copyable`
**Storage**: `Buffer<Element>.Ring` (dynamically-growing ring buffer)
**Copyable**: Conditional (`Copyable where Element: Copyable`)

| Canonical Operation | Method/Property | Complexity | Source File |
|---------------------|-----------------|------------|-------------|
| enqueue(x) | `mutating func enqueue(_ element: consuming Element)` | O(1) amortized | `Queue.Dynamic ~Copyable.swift:39` |
| enqueue(x) (CoW) | `mutating func enqueue(_ element: Element)` | O(1) amortized | `Queue.Dynamic Copyable.swift:47` |
| dequeue() | `mutating func dequeue() -> Element?` | O(1) | `Queue.Dynamic ~Copyable.swift:48` |
| dequeue() (CoW) | `mutating func dequeue() -> Element?` | O(1) | `Queue.Dynamic Copyable.swift:56` |
| peek() (Copyable) | `func peek() -> Element?` | O(1) | `Queue.Dynamic Copyable.swift:87` |
| peek() (~Copyable) | `func peek<R>(_ body: (borrowing Element) -> R) -> R?` | O(1) | `Queue.Dynamic ~Copyable.swift:81` |
| is_empty | `var isEmpty: Bool` | O(1) | `Queue.Dynamic ~Copyable.swift:24` |
| count | `var count: Index<Element>.Count` | O(1) | `Queue.Dynamic ~Copyable.swift:20` |

**Additional operations (beyond canonical)**:

| Operation | Method/Property | Complexity | Source File |
|-----------|-----------------|------------|-------------|
| capacity | `var capacity: Index<Element>.Count` | O(1) | `Queue.Dynamic ~Copyable.swift:28` |
| clear | `mutating func clear(keepingCapacity: Bool = true)` | O(n) | `Queue.Dynamic ~Copyable.swift:61` |
| clear (CoW) | `mutating func clear(keepingCapacity: Bool = true)` | O(n) | `Queue.Dynamic Copyable.swift:69` |
| reserve | `mutating func reserve(_ minimumCapacity: Index<Element>.Count)` | O(n) worst | `Queue.Dynamic ~Copyable.swift:118` |
| compact | `mutating func compact()` | O(n) | `Queue.Dynamic ~Copyable.swift:129` / `Queue.Dynamic Copyable.swift:213` |
| forEach | `func forEach(_ body: (borrowing Element) -> Void)` | O(n) | `Queue.Dynamic ~Copyable.swift:103` |
| subscript | `subscript(index: Index) -> Element` | O(1) | `Queue.Index.swift:44` / `Queue.Dynamic Copyable.swift:23` |
| element(at:) | `func element(at index: Index) -> Element?` (Copyable) | O(1) | `Queue.Index.swift:64` |
| drain | `mutating func drain(_ body: (consuming Element) -> Void)` (Copyable) | O(n) | `Queue.Dynamic Copyable.swift:179` |
| drain accessor | `var drain: Property<Sequence.Drain, Self>.View` (Copyable) | -- | `Queue.Dynamic Copyable.swift:193` |
| removeAll | `mutating func removeAll()` (Copyable) | O(n) | `Queue.Dynamic Copyable.swift:162` |

**Protocol conformances** (Copyable elements):
- `Swift.Sequence`, `Swift.Collection`, `Swift.BidirectionalCollection`, `Swift.RandomAccessCollection`
- `Sequence.Protocol`, `Sequence.Clearable`, `Sequence.Drain.Protocol`
- `Input.Streaming`, `Input.Protocol` (checkpoint/restore)
- `Equatable` (where `Element: Equatable`), `Hashable` (where `Element: Hashable`)
- `ExpressibleByArrayLiteral`, `CustomStringConvertible`
- `Copyable` (conditional), `Sendable` (conditional)

---

### Variant: Queue.Fixed

**Type**: `Queue<Element: ~Copyable>.Fixed: ~Copyable`
**Storage**: `Buffer<Element>.Ring.Bounded` (fixed-capacity ring buffer)
**Copyable**: Conditional (`Copyable where Element: Copyable`)

| Canonical Operation | Method/Property | Complexity | Source File |
|---------------------|-----------------|------------|-------------|
| enqueue(x) | `mutating func enqueue(_ element: consuming Element) throws(Queue<Element>.Fixed.Error)` | O(1) | `Queue.Bounded.swift:43` |
| enqueue(x) (CoW) | `mutating func enqueue(_ element: Element) throws(Queue<Element>.Fixed.Error)` | O(1) | `Queue.Bounded.swift:84` |
| dequeue() | `mutating func dequeue() -> Element?` | O(1) | `Queue.Bounded.swift:55` |
| dequeue() (CoW) | `mutating func dequeue() -> Element?` | O(1) | `Queue.Bounded.swift:93` |
| peek() (Copyable) | `func peek() -> Element?` | O(1) | `Queue.Bounded.swift:122` |
| peek() (~Copyable) | `func peek<R>(_ body: (borrowing Element) -> R) -> R?` | O(1) | `Queue.Bounded.swift:112` |
| is_empty | `var isEmpty: Bool` | O(1) | `Queue.Bounded.swift:27` |
| count | `var count: Index<Element>.Count` | O(1) | `Queue.Bounded.swift:23` |

**Additional operations (beyond canonical)**:

| Operation | Method/Property | Complexity | Source File |
|-----------|-----------------|------------|-------------|
| isFull | `var isFull: Bool` | O(1) | `Queue.Bounded.swift:31` |
| capacity | `let capacity: Index.Count` | O(1) | `Queue.swift:197` (declaration) |
| clear | `mutating func clear()` | O(n) | `Queue.Bounded.swift:68` |
| forEach | `func forEach(_ body: (borrowing Element) -> Void)` | O(n) | `Queue.Bounded.swift:138` |
| drain | `mutating func drain(_ body: (consuming Element) -> Void)` (Copyable) | O(n) | `Queue.Fixed Copyable.swift:102` |
| drain accessor | `var drain: Property<Sequence.Drain, Self>.View` (Copyable) | -- | `Queue.Fixed Copyable.swift:116` |
| removeAll | `mutating func removeAll()` (Copyable) | O(n) | `Queue.Fixed Copyable.swift:84` |

**Protocol conformances** (Copyable elements):
- `Swift.Sequence`, `Sequence.Protocol`, `Sequence.Clearable`, `Sequence.Drain.Protocol`
- `Input.Streaming`, `Input.Protocol` (checkpoint/restore)
- `Copyable` (conditional), `Sendable` (conditional)

---

### Variant: Queue.Static

**Type**: `Queue<Element: ~Copyable>.Static<let capacity: Int>: ~Copyable`
**Storage**: `Buffer<Element>.Ring.Inline<capacity>` (inline, zero-allocation)
**Copyable**: Unconditionally `~Copyable` (deinit requirement)

| Canonical Operation | Method/Property | Complexity | Source File |
|---------------------|-----------------|------------|-------------|
| enqueue(x) | `mutating func enqueue(_ element: consuming Element) throws(Queue<Element>.Static.Error)` | O(1) | `Queue.Static.swift:42` |
| dequeue() | `mutating func dequeue() -> Element?` | O(1) | `Queue.Static.swift:54` |
| peek() (Copyable) | `func peek() -> Element?` | O(1) | `Queue.Static.swift:97` |
| peek() (~Copyable) | `func peek<R>(_ body: (borrowing Element) -> R) -> R?` | O(1) | `Queue.Static.swift:81` |
| is_empty | `var isEmpty: Bool` | O(1) | `Queue.Static.swift:26` |
| count | `var count: Index<Element>.Count` | O(1) | `Queue.Static.swift:22` |

**Additional operations (beyond canonical)**:

| Operation | Method/Property | Complexity | Source File |
|-----------|-----------------|------------|-------------|
| isFull | `var isFull: Bool` | O(1) | `Queue.Static.swift:30` |
| clear | `mutating func clear()` | O(n) | `Queue.Static.swift:65` |
| forEach | `func forEach(_ body: (borrowing Element) -> Void)` | O(n) | `Queue.Static.swift:115` |
| drain | `mutating func drain(_ body: (consuming Element) -> Void)` (Copyable) | O(n) | `Queue.Static Copyable.swift:109` |
| removeAll | `mutating func removeAll()` (Copyable) | O(n) | `Queue.Static Copyable.swift:92` |

**Protocol conformances** (Copyable elements):
- `Sequence.Protocol`, `Sequence.Clearable`, `Sequence.Drain.Protocol`
- `Input.Streaming`, `Input.Protocol` (checkpoint/restore)
- `Sendable` (conditional)

**Property.View accessors** (Copyable elements): `drain`, `forEach`, `satisfies`, `reduce`, `contains`, `drop`, `prefix`

---

### Variant: Queue.Small

**Type**: `Queue<Element: ~Copyable>.Small<let inlineCapacity: Int>: ~Copyable`
**Storage**: `Buffer<Element>.Ring.Small<inlineCapacity>` (inline with heap spill)
**Copyable**: Unconditionally `~Copyable` (deinit requirement)

| Canonical Operation | Method/Property | Complexity | Source File |
|---------------------|-----------------|------------|-------------|
| enqueue(x) | `mutating func enqueue(_ element: consuming Element)` | O(1) amortized | `Queue.Small.swift:41` |
| dequeue() | `mutating func dequeue() -> Element?` | O(1) | `Queue.Small.swift:50` |
| peek() (Copyable) | `func peek() -> Element?` | O(1) | `Queue.Small.swift:96` |
| peek() (~Copyable) | `func peek<R>(_ body: (borrowing Element) -> R) -> R?` | O(1) | `Queue.Small.swift:82` |
| is_empty | `var isEmpty: Bool` | O(1) | `Queue.Small.swift:26` |
| count | `var count: Index<Element>.Count` | O(1) | `Queue.Small.swift:22` |

**Additional operations (beyond canonical)**:

| Operation | Method/Property | Complexity | Source File |
|-----------|-----------------|------------|-------------|
| capacity | `var capacity: Index<Element>.Count` | O(1) | `Queue.Small.swift:30` |
| isSpilled | `var isSpilled: Bool` | O(1) | `Queue.swift:162` |
| clear | `mutating func clear(keepingCapacity: Bool = true)` | O(n) | `Queue.Small.swift:63` |
| forEach | `func forEach(_ body: (borrowing Element) -> Void)` | O(n) | `Queue.Small.swift:114` |
| drain | `mutating func drain(_ body: (consuming Element) -> Void)` (Copyable) | O(n) | `Queue.Small Copyable.swift:111` |
| removeAll | `mutating func removeAll()` (Copyable) | O(n) | `Queue.Small Copyable.swift:93` |

**Protocol conformances** (Copyable elements):
- `Sequence.Protocol`, `Sequence.Clearable`, `Sequence.Drain.Protocol`
- `Input.Streaming`, `Input.Protocol` (checkpoint/restore)
- `Sendable` (conditional)

**Property.View accessors** (Copyable elements): `drain`, `forEach`, `satisfies`, `reduce`, `contains`, `drop`, `prefix`

---

### Variant: Queue.Linked

**Type**: `Queue<Element: ~Copyable>.Linked: ~Copyable`
**Storage**: `Buffer<Element>.Linked<1>` (arena-based linked list)
**Copyable**: Conditional (`Copyable where Element: Copyable`)

| Canonical Operation | Method/Property | Complexity | Source File |
|---------------------|-----------------|------------|-------------|
| enqueue(x) | `mutating func enqueue(_ element: consuming Element)` | O(1) amortized | `Queue.Linked ~Copyable.swift:60` |
| enqueue(x) (CoW) | `mutating func enqueue(_ element: Element)` | O(1) amortized | `Queue.Linked Copyable.swift:29` |
| dequeue() | `mutating func dequeue() -> Element?` | O(1) | `Queue.Linked ~Copyable.swift:70` |
| dequeue() (CoW) | `mutating func dequeue() -> Element?` | O(1) | `Queue.Linked Copyable.swift:40` |
| peek() (Copyable) | `func peek() -> Element?` | O(1) | `Queue.Linked Copyable.swift:69` |
| peek() (~Copyable) | `func peek<R>(_ body: (borrowing Element) -> R) -> R?` | O(1) | `Queue.Linked ~Copyable.swift:99` |
| is_empty | `var isEmpty: Bool` | O(1) | `Queue.Linked ~Copyable.swift:24` |
| count | `var count: Index<Element>.Count` | O(1) | `Queue.Linked ~Copyable.swift:20` |

**Additional operations (beyond canonical)**:

| Operation | Method/Property | Complexity | Source File |
|-----------|-----------------|------------|-------------|
| capacity | `var capacity: Index<Element>.Count` | O(1) | `Queue.Linked ~Copyable.swift:28` |
| reserve | `mutating func reserve(_ minimumCapacity: Int)` | O(n) worst | `Queue.Linked ~Copyable.swift:47` |
| clear | `mutating func clear(keepingCapacity: Bool = true)` | O(n) | `Queue.Linked ~Copyable.swift:80` / `Queue.Linked Copyable.swift:51` |
| forEach | `func forEach(_ body: (borrowing Element) -> Void)` | O(n) | `Queue.Linked ~Copyable.swift:114` |
| drain | `mutating func drain(_ body: (consuming Element) -> Void)` (Copyable) | O(n) | `Queue.Linked Copyable.swift:147` |
| drain accessor | `var drain: Property<Sequence.Drain, Self>.View` (Copyable) | -- | `Queue.Linked Copyable.swift:161` |
| removeAll | `mutating func removeAll()` (Copyable) | O(n) | `Queue.Linked Copyable.swift:130` |
| init(reservingCapacity:) | `init(reservingCapacity capacity: Int) throws(__QueueLinkedError)` | O(1) | `Queue.swift:265` |

**Protocol conformances** (Copyable elements):
- `Swift.Sequence`, `Sequence.Protocol`, `Sequence.Clearable`, `Sequence.Drain.Protocol`
- `Equatable` (where `Element: Equatable`), `Hashable` (where `Element: Hashable`)
- `Copyable` (conditional), `Sendable` (conditional)

---

### Sub-Variant: Queue.Linked.Fixed

**Type**: `Queue<Element: ~Copyable>.Linked.Fixed: ~Copyable`
**Storage**: `Buffer<Element>.Linked<1>` (fixed-capacity arena-based linked list)
**Copyable**: Conditional (`Copyable where Element: Copyable`)

| Canonical Operation | Method/Property | Complexity | Source File |
|---------------------|-----------------|------------|-------------|
| enqueue(x) | `mutating func enqueue(_ element: consuming Element) throws(__QueueLinkedBoundedError)` | O(1) | `Queue.Linked.Bounded.swift:40` |
| enqueue(x) (CoW) | `mutating func enqueue(_ element: Element) throws(__QueueLinkedBoundedError)` | O(1) | `Queue.Linked.Bounded.swift:78` |
| dequeue() | `mutating func dequeue() -> Element?` | O(1) | `Queue.Linked.Bounded.swift:50` |
| dequeue() (CoW) | `mutating func dequeue() -> Element?` | O(1) | `Queue.Linked.Bounded.swift:89` |
| peek() (Copyable) | `func peek() -> Element?` | O(1) | `Queue.Linked.Bounded.swift:129` |
| peek() (~Copyable) | `func peek<R>(_ body: (borrowing Element) -> R) -> R?` | O(1) | `Queue.Linked.Bounded.swift:115` |
| is_empty | `var isEmpty: Bool` | O(1) | `Queue.Linked.Bounded.swift:24` |
| count | `var count: Index<Element>.Count` | O(1) | `Queue.Linked.Bounded.swift:20` |

**Additional operations (beyond canonical)**:

| Operation | Method/Property | Complexity | Source File |
|-----------|-----------------|------------|-------------|
| isFull | `var isFull: Bool` | O(1) | `Queue.Linked.Bounded.swift:28` |
| capacity | `let capacity: Index<Element>.Count` | O(1) | `Queue.swift:294` (declaration) |
| clear | `mutating func clear()` | O(n) | `Queue.Linked.Bounded.swift:58` / `Queue.Linked.Bounded.swift:98` |
| forEach | `func forEach(_ body: (borrowing Element) -> Void)` | O(n) | `Queue.Linked.Bounded.swift:144` |

**Protocol conformances** (Copyable elements):
- `Swift.Sequence`, `Equatable` (where `Element: Equatable`), `Hashable` (where `Element: Hashable`)
- `Copyable` (conditional), `Sendable` (conditional)

---

### Sub-Variant: Queue.Linked.Inline

**Type**: `Queue<Element: Copyable>.Linked.Inline<let capacity: Int>: ~Copyable`
**Storage**: `List<Element>.Linked<1>.Inline<capacity>` (inline linked list)
**Constraint**: Requires `Element: Copyable`
**Copyable**: Unconditionally `~Copyable`

| Canonical Operation | Method/Property | Complexity | Source File |
|---------------------|-----------------|------------|-------------|
| enqueue(x) | `mutating func enqueue(_ element: Element) throws(__QueueLinkedInlineError)` | O(1) | `Queue.Linked.Inline+Small.swift:39` |
| dequeue() | `mutating func dequeue() -> Element?` | O(1) | `Queue.Linked.Inline+Small.swift:54` |
| peek() | `func peek() -> Element?` | O(1) | `Queue.Linked.Inline+Small.swift:73` |
| is_empty | `var isEmpty: Bool` | O(1) | `Queue.Linked.Inline+Small.swift:25` |
| count | `var count: Index<Element>.Count` | O(1) | `Queue.Linked.Inline+Small.swift:22` |

**Additional operations (beyond canonical)**:

| Operation | Method/Property | Complexity | Source File |
|-----------|-----------------|------------|-------------|
| isFull | `var isFull: Bool` | O(1) | `Queue.Linked.Inline+Small.swift:28` |
| clear | `mutating func clear()` | O(n) | `Queue.Linked.Inline+Small.swift:61` |
| forEach | `func forEach(_ body: (Element) -> Void)` | O(n) | `Queue.Linked.Inline+Small.swift:87` |

**Protocol conformances**: `Sendable` (conditional)

---

### Sub-Variant: Queue.Linked.Small

**Type**: `Queue<Element: Copyable>.Linked.Small<let inlineCapacity: Int>: ~Copyable`
**Storage**: `List<Element>.Linked<1>.Small<inlineCapacity>` (inline with heap spill)
**Constraint**: Requires `Element: Copyable`
**Copyable**: Unconditionally `~Copyable`

| Canonical Operation | Method/Property | Complexity | Source File |
|---------------------|-----------------|------------|-------------|
| enqueue(x) | `mutating func enqueue(_ element: Element)` | O(1) amortized | `Queue.Linked.Inline+Small.swift:132` |
| dequeue() | `mutating func dequeue() -> Element?` | O(1) | `Queue.Linked.Inline+Small.swift:140` |
| peek() | `func peek() -> Element?` | O(1) | `Queue.Linked.Inline+Small.swift:159` |
| is_empty | `var isEmpty: Bool` | O(1) | `Queue.Linked.Inline+Small.swift:119` |
| count | `var count: Index<Element>.Count` | O(1) | `Queue.Linked.Inline+Small.swift:116` |

**Additional operations (beyond canonical)**:

| Operation | Method/Property | Complexity | Source File |
|-----------|-----------------|------------|-------------|
| capacity | `var capacity: Index<Element>.Count` | O(1) | `Queue.Linked.Inline+Small.swift:122` |
| isSpilled | `var isSpilled: Bool` | O(1) | `Queue.swift:562` |
| clear | `mutating func clear()` | O(n) | `Queue.Linked.Inline+Small.swift:147` |
| forEach | `func forEach(_ body: (Element) -> Void)` | O(n) | `Queue.Linked.Inline+Small.swift:173` |

**Protocol conformances**: `Sendable` (conditional)

---

### Variant: Queue.DoubleEnded (Dynamic)

**Type**: `Queue<Element: ~Copyable>.DoubleEnded: ~Copyable` (aliased as `Deque<Element>`)
**Storage**: `Buffer<Element>.Ring` (dynamically-growing ring buffer)
**Copyable**: Conditional (`Copyable where Element: Copyable`)

| Canonical Deque Operation | Method/Property | Complexity | Source File |
|---------------------------|-----------------|------------|-------------|
| push_front(x) | `mutating func push(_ element: consuming Element, to: .front)` | O(1) amortized | `Queue.DoubleEnded.swift:84` |
| push_back(x) | `mutating func push(_ element: consuming Element, to: .back)` | O(1) amortized | `Queue.DoubleEnded.swift:84` |
| push_front(x) (CoW) | `mutating func push(_ element: Element, to: .front)` | O(1) amortized | `Queue.DoubleEnded.swift:168` |
| push_back(x) (CoW) | `mutating func push(_ element: Element, to: .back)` | O(1) amortized | `Queue.DoubleEnded.swift:168` |
| pop_front() | `mutating func pop(from: .front) -> Element?` | O(1) | `Queue.DoubleEnded.swift:97` |
| pop_back() | `mutating func pop(from: .back) -> Element?` | O(1) | `Queue.DoubleEnded.swift:97` |
| pop_front() (CoW) | `mutating func pop(from: .front) -> Element?` | O(1) | `Queue.DoubleEnded.swift:179` |
| pop_back() (CoW) | `mutating func pop(from: .back) -> Element?` | O(1) | `Queue.DoubleEnded.swift:179` |
| peek_front() (~Copyable) | `func peek<R>(at: .front, _ body: (borrowing Element) -> R) -> R?` | O(1) | `Queue.DoubleEnded.swift:134` |
| peek_back() (~Copyable) | `func peek<R>(at: .back, _ body: (borrowing Element) -> R) -> R?` | O(1) | `Queue.DoubleEnded.swift:134` |
| peek_front() (Copyable) | `func peek(at: .front) -> Element?` | O(1) | `Queue.DoubleEnded.swift:206` |
| peek_back() (Copyable) | `func peek(at: .back) -> Element?` | O(1) | `Queue.DoubleEnded.swift:206` |
| is_empty | `var isEmpty: Bool` | O(1) | `Queue.DoubleEnded.swift:60` |
| count | `var count: Index<Element>.Count` | O(1) | `Queue.DoubleEnded.swift:56` |

**Additional operations (beyond canonical)**:

| Operation | Method/Property | Complexity | Source File |
|-----------|-----------------|------------|-------------|
| capacity | `var capacity: Index<Element>.Count` | O(1) | `Queue.DoubleEnded.swift:64` |
| take(from:) | `mutating func take(from position: Position) -> Element?` | O(1) | `Queue.DoubleEnded.swift:111` |
| reserve | `mutating func reserve(_ minimumCapacity: Index<Element>.Count)` | O(n) worst | `Queue.DoubleEnded.swift:72` |
| clear | `mutating func clear(keepingCapacity: Bool = true)` | O(n) | `Queue.DoubleEnded.swift:119` |
| forEach | `func forEach(_ body: (borrowing Element) -> Void)` | O(n) | `Queue.DoubleEnded.swift:152` |
| drain | `mutating func drain(_ body: (consuming Element) -> Void)` (Copyable) | O(n) | `Queue.DoubleEnded Copyable.swift:70` |
| drain accessor | `var drain: Property<Sequence.Drain, Self>.View` (Copyable) | -- | `Queue.DoubleEnded Copyable.swift:82` |
| removeAll | `mutating func removeAll()` (Copyable) | O(n) | `Queue.DoubleEnded Copyable.swift:55` |
| subscript | `subscript(index: Queue.Index) -> Element` (Copyable) | O(1) | `Queue.DoubleEnded Copyable.swift:27` |
| init(reservingCapacity:) | `init(reservingCapacity capacity: Index.Count)` | O(1) | `Queue.swift:338` |
| init(_ elements:) | `init<S: Swift.Sequence>(_ elements: S)` (Copyable) | O(n) | `Queue.DoubleEnded.swift:599` |

**Property.View positional accessors** (Copyable elements):

| Accessor | Operations | Source File |
|----------|-----------|-------------|
| `deque.front.push(_:)` | Push to front | `Queue.DoubleEnded.Accessor.swift:127` |
| `deque.front.pop()` | Pop from front (throws) | `Queue.DoubleEnded.Accessor.swift:136` |
| `deque.front.take` | Take from front (optional) | `Queue.DoubleEnded.Accessor.swift:148` |
| `deque.front.peek` | Peek front (optional) | `Queue.DoubleEnded.Accessor.swift:116` |
| `deque.back.push(_:)` | Push to back | `Queue.DoubleEnded.Accessor.swift:199` |
| `deque.back.pop()` | Pop from back (throws) | `Queue.DoubleEnded.Accessor.swift:209` |
| `deque.back.take` | Take from back (optional) | `Queue.DoubleEnded.Accessor.swift:221` |
| `deque.back.peek` | Peek back (optional) | `Queue.DoubleEnded.Accessor.swift:189` |
| `deque.peek.front` | Non-mutating peek front | `Queue.DoubleEnded.Accessor.swift:50` |
| `deque.peek.back` | Non-mutating peek back | `Queue.DoubleEnded.Accessor.swift:59` |

**Protocol conformances** (Copyable elements):
- `Swift.Sequence`, `Swift.Collection`, `Swift.BidirectionalCollection`, `Swift.RandomAccessCollection`
- `Sequence.Protocol`, `Sequence.Clearable`, `Sequence.Drain.Protocol`
- `Collection.Indexed`, `Collection.Bidirectional`, `Collection.Protocol`, `Collection.Access.Random`
- `Equatable` (where `Element: Equatable`), `Hashable` (where `Element: Hashable`)
- `ExpressibleByArrayLiteral`, `CustomStringConvertible`
- `Copyable` (conditional), `Sendable` (conditional)

---

### Sub-Variant: Queue.DoubleEnded.Fixed

**Type**: `Queue<Element: ~Copyable>.DoubleEnded.Fixed: ~Copyable`
**Storage**: `Buffer<Element>.Ring.Bounded` (fixed-capacity ring buffer)
**Copyable**: Conditional (`Copyable where Element: Copyable`)

| Canonical Deque Operation | Method/Property | Complexity | Source File |
|---------------------------|-----------------|------------|-------------|
| push_front(x) | `mutating func push(_ element: consuming Element, to: .front) throws(Error)` | O(1) | `Queue.DoubleEnded.swift:246` |
| push_back(x) | `mutating func push(_ element: consuming Element, to: .back) throws(Error)` | O(1) | `Queue.DoubleEnded.swift:246` |
| pop_front() | `mutating func pop(from: .front) -> Element?` | O(1) | `Queue.DoubleEnded.swift:261` |
| pop_back() | `mutating func pop(from: .back) -> Element?` | O(1) | `Queue.DoubleEnded.swift:261` |
| peek (Copyable) | `func peek(at position: Position) -> Element?` | O(1) | `Queue.DoubleEnded.swift:355` |
| peek (~Copyable) | `func peek<R>(at position: Position, _ body:) -> R?` | O(1) | `Queue.DoubleEnded.swift:279` |
| is_empty | `var isEmpty: Bool` | O(1) | `Queue.DoubleEnded.swift:232` |
| count | `var count: Index<Element>.Count` | O(1) | `Queue.DoubleEnded.swift:228` |

**Additional operations (beyond canonical)**:

| Operation | Method/Property | Complexity | Source File |
|-----------|-----------------|------------|-------------|
| isFull | `var isFull: Bool` | O(1) | `Queue.DoubleEnded.swift:236` |
| capacity | `let capacity: Index.Count` | O(1) | `Queue.swift:352` (declaration) |
| take(from:) | `mutating func take(from position: Position) -> Element?` | O(1) | `Queue.DoubleEnded.swift:273` |
| clear | `mutating func clear()` | O(n) | `Queue.DoubleEnded.swift:294` |
| forEach | `func forEach(_ body: (borrowing Element) -> Void)` | O(n) | `Queue.DoubleEnded.swift:300` |
| drain | `mutating func drain(_ body: (consuming Element) -> Void)` (Copyable) | O(n) | `Queue.DoubleEnded Copyable.swift:207` |
| drain accessor | `var drain: Property<Sequence.Drain, Self>.View` (Copyable) | -- | `Queue.DoubleEnded Copyable.swift:237` |
| removeAll | `mutating func removeAll()` (Copyable) | O(n) | `Queue.DoubleEnded Copyable.swift:191` |
| subscript | `subscript(index: Queue.Index) -> Element` (Copyable) | O(1) | `Queue.DoubleEnded Copyable.swift:223` |

**Protocol conformances** (Copyable elements):
- `Swift.Sequence`, `Swift.Collection`, `Swift.BidirectionalCollection`, `Swift.RandomAccessCollection`
- `Sequence.Protocol`, `Sequence.Clearable`, `Sequence.Drain.Protocol`
- `Collection.Indexed`, `Collection.Bidirectional`, `Collection.Protocol`, `Collection.Access.Random`
- `Copyable` (conditional), `Sendable` (conditional)

---

### Sub-Variant: Queue.DoubleEnded.Static

**Type**: `Queue<Element: ~Copyable>.DoubleEnded.Static<let capacity: Int>: ~Copyable`
**Storage**: `Buffer<Element>.Ring.Inline<capacity>` (inline, zero-allocation)
**Copyable**: Unconditionally `~Copyable` (deinit requirement)

| Canonical Deque Operation | Method/Property | Complexity | Source File |
|---------------------------|-----------------|------------|-------------|
| push_front(x) | `mutating func push(_ element: consuming Element, to: .front) throws(Error)` | O(1) | `Queue.DoubleEnded.swift:383` |
| push_back(x) | `mutating func push(_ element: consuming Element, to: .back) throws(Error)` | O(1) | `Queue.DoubleEnded.swift:383` |
| pop_front() | `mutating func pop(from: .front) -> Element?` | O(1) | `Queue.DoubleEnded.swift:398` |
| pop_back() | `mutating func pop(from: .back) -> Element?` | O(1) | `Queue.DoubleEnded.swift:398` |
| peek (~Copyable) | `func peek<R>(at position: Position, _ body:) -> R?` | O(1) | `Queue.DoubleEnded.swift:416` |
| is_empty | `var isEmpty: Bool` | O(1) | `Queue.DoubleEnded.swift:375` |
| count | `var count: Index<Element>.Count` | O(1) | `Queue.DoubleEnded.swift:371` |

**Additional operations (beyond canonical)**:

| Operation | Method/Property | Complexity | Source File |
|-----------|-----------------|------------|-------------|
| isFull | `var isFull: Bool` | O(1) | `Queue.DoubleEnded.swift:379` |
| take(from:) | `mutating func take(from position: Position) -> Element?` | O(1) | `Queue.DoubleEnded.swift:410` |
| clear | `mutating func clear()` | O(n) | `Queue.DoubleEnded.swift:431` |
| forEach | `func forEach(_ body: (borrowing Element) -> Void)` | O(n) | `Queue.DoubleEnded.swift:437` |
| drain | `mutating func drain(_ body: (consuming Element) -> Void)` (Copyable) | O(n) | `Queue.DoubleEnded Copyable.swift:372` |
| removeAll | `mutating func removeAll()` (Copyable) | O(n) | `Queue.DoubleEnded Copyable.swift:357` |

**Protocol conformances** (Copyable elements):
- `Sequence.Protocol`, `Sequence.Clearable`, `Sequence.Drain.Protocol`
- `Sendable` (conditional)

**Property.View accessors** (Copyable elements): `drain`, `forEach`, `satisfies`, `first`, `reduce`, `contains`, `drop`, `prefix`

---

### Sub-Variant: Queue.DoubleEnded.Small

**Type**: `Queue<Element: ~Copyable>.DoubleEnded.Small<let inlineCapacity: Int>: ~Copyable`
**Storage**: `Buffer<Element>.Ring.Small<inlineCapacity>` (inline with heap spill)
**Copyable**: Unconditionally `~Copyable` (deinit requirement)

| Canonical Deque Operation | Method/Property | Complexity | Source File |
|---------------------------|-----------------|------------|-------------|
| push_front(x) | `mutating func push(_ element: consuming Element, to: .front)` | O(1) amortized | `Queue.DoubleEnded.swift:455` |
| push_back(x) | `mutating func push(_ element: consuming Element, to: .back)` | O(1) amortized | `Queue.DoubleEnded.swift:455` |
| pop_front() | `mutating func pop(from: .front) -> Element?` | O(1) | `Queue.DoubleEnded.swift:469` |
| pop_back() | `mutating func pop(from: .back) -> Element?` | O(1) | `Queue.DoubleEnded.swift:469` |
| peek (~Copyable) | `func peek<R>(at position: Position, _ body:) -> R?` | O(1) | `Queue.DoubleEnded.swift:487` |
| is_empty | `var isEmpty: Bool` | O(1) | `Queue.DoubleEnded.swift:451` |
| count | `var count: Index<Element>.Count` | O(1) | `Queue.DoubleEnded.swift:447` |

**Additional operations (beyond canonical)**:

| Operation | Method/Property | Complexity | Source File |
|-----------|-----------------|------------|-------------|
| isSpilled | `var isSpilled: Bool` | O(1) | `Queue.swift:413` |
| take(from:) | `mutating func take(from position: Position) -> Element?` | O(1) | `Queue.DoubleEnded.swift:481` |
| clear | `mutating func clear()` | O(n) | `Queue.DoubleEnded.swift:502` |
| forEach | `func forEach(_ body: (borrowing Element) -> Void)` | O(n) | `Queue.DoubleEnded.swift:508` |
| drain | `mutating func drain(_ body: (consuming Element) -> Void)` (Copyable) | O(n) | `Queue.DoubleEnded Copyable.swift:552` |
| removeAll | `mutating func removeAll()` (Copyable) | O(n) | `Queue.DoubleEnded Copyable.swift:536` |

**Protocol conformances** (Copyable elements):
- `Sequence.Protocol`, `Sequence.Clearable`, `Sequence.Drain.Protocol`
- `Sendable` (conditional)

**Property.View accessors** (Copyable elements): `drain`, `forEach`, `satisfies`, `first`, `reduce`, `contains`, `drop`, `prefix`

---

## Gap Analysis

### Present and Correctly Mapped

All FIFO queue variants provide the five canonical queue operations:

| Canonical Operation | Present in ALL FIFO Variants | Notes |
|---------------------|------------------------------|-------|
| enqueue(x) | Yes | Both `~Copyable` (consuming) and Copyable (CoW) overloads where applicable |
| dequeue() | Yes | Returns `Optional` -- consistent nil-on-empty semantics |
| peek()/front() | Yes | Dual API: `peek() -> Element?` (Copyable) and `peek(_:) -> R?` (closure, ~Copyable) |
| is_empty | Yes | `var isEmpty: Bool` on every variant |
| count/size | Yes | `var count: Index<Element>.Count` on every variant |

All DoubleEnded variants provide the six canonical deque operations:

| Canonical Operation | Present in ALL Deque Variants | Notes |
|---------------------|-------------------------------|-------|
| push_front(x) | Yes | `push(_:to: .front)` -- position-parameterized |
| push_back(x) | Yes | `push(_:to: .back)` -- position-parameterized |
| pop_front() | Yes | `pop(from: .front)` -- returns Optional |
| pop_back() | Yes | `pop(from: .back)` -- returns Optional |
| peek_front() | Yes | `peek(at: .front)` or `peek(at: .front, _:)` |
| peek_back() | Yes | `peek(at: .back)` or `peek(at: .back, _:)` |

The DoubleEnded (Dynamic) variant additionally provides the `.front`/`.back` Property.View accessors (`deque.front.push()`, `deque.front.pop()`, `deque.back.push()`, `deque.back.pop()`, etc.) and the `deque.peek.front`/`deque.peek.back` non-mutating PeekAccessor for ergonomic positional access.

### Missing -- Should Add (Primitives Layer)

| Missing Operation | Applicable Variants | Priority | Rationale |
|-------------------|---------------------|----------|-----------|
| `Equatable` | Queue.Fixed, Queue.Static, Queue.Small | Medium | Element-wise FIFO-order comparison is core queue semantics; already present on Queue (Dynamic) and Queue.Linked |
| `Hashable` | Queue.Fixed, Queue.Static, Queue.Small | Medium | Follows from Equatable; already present on Queue (Dynamic) and Queue.Linked |
| `Equatable` | Queue.DoubleEnded.Fixed, Queue.DoubleEnded.Static, Queue.DoubleEnded.Small | Medium | Already present on Queue.DoubleEnded (Dynamic) |
| `Hashable` | Queue.DoubleEnded.Fixed, Queue.DoubleEnded.Static, Queue.DoubleEnded.Small | Medium | Already present on Queue.DoubleEnded (Dynamic) |
| `CustomStringConvertible` | All non-Dynamic variants | Low | Debugging ergonomics; already present on Queue (Dynamic) and Queue.DoubleEnded (Dynamic) |
| `ExpressibleByArrayLiteral` | Queue.Fixed, Queue.Linked | Low | Construction convenience; already present on Queue (Dynamic) and Queue.DoubleEnded (Dynamic) |
| `Equatable` | Queue.Linked.Inline, Queue.Linked.Small | Low | Consistency with Queue.Linked and Queue.Linked.Fixed |
| `Hashable` | Queue.Linked.Inline, Queue.Linked.Small | Low | Same |
| `peek(at:) -> Element?` (Copyable) | Queue.DoubleEnded.Static, Queue.DoubleEnded.Small | Low | Currently only have closure-based `peek(at:_:)`. The Dynamic and Fixed deque variants have both. |
| `front`/`back` Property.View accessors | Queue.DoubleEnded.Fixed, Queue.DoubleEnded.Static, Queue.DoubleEnded.Small | Low | Currently only on Queue.DoubleEnded (Dynamic). Consistent ergonomics would be valuable. |
| `Collection` conformances | Queue.Fixed | Low | Dynamic queue has it; Fixed could benefit from indexed access too |

### Missing -- Intentionally Absent (Higher Layer)

| Operation | Reason for Absence |
|-----------|-------------------|
| `find(_:)` / `contains(_:)` requiring `Equatable` | Layer 1 primitives do not impose `Equatable` constraint on elements for searching. Available via Sequence conformance (stdlib `contains`) or `contains` Property.View accessor on Static/Small variants. |
| `sort()` / `sorted()` | Sorting violates FIFO ordering discipline. Not appropriate for queue abstraction. |
| `insert(at:)` / `remove(at:)` | Arbitrary-position insertion/removal is deque-array territory, not queue discipline. |
| `map()` / `filter()` / `reduce()` | Available via `Sequence` conformance or Property.View accessors. Queue does not need to reimplement. |
| Priority queue operations | `Queue.Priority` would be a separate type with heap-based storage. Not part of FIFO/deque discipline. |
| `merge()` / `concatenate()` | Queue merging belongs at foundations layer (composed operation). |

---

## Summary: Variant Coverage Matrix

| Canonical Op | Queue | .Fixed | .Static | .Small | .Linked | .Linked.Fixed | .Linked.Inline | .Linked.Small | .DoubleEnded | .DE.Fixed | .DE.Static | .DE.Small |
|:---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| enqueue / push | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| dequeue / pop | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| peek (Copyable) | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | -- | -- |
| peek (closure) | Y | Y | Y | Y | Y | Y | -- | -- | Y | Y | Y | Y |
| isEmpty | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| count | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| isFull | -- | Y | Y | -- | -- | Y | Y | -- | -- | Y | Y | -- |
| capacity | Y | Y | -- | Y | Y | Y | -- | Y | Y | Y | -- | -- |
| clear | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| forEach | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| reserve | Y | -- | -- | -- | Y | -- | -- | -- | Y | -- | -- | -- |
| compact | Y | -- | -- | -- | -- | -- | -- | -- | -- | -- | -- | -- |
| subscript | Y | -- | -- | -- | -- | -- | -- | -- | Y | Y | -- | -- |
| drain | Y | Y | Y | Y | Y | -- | -- | -- | Y | Y | Y | Y |
| Equatable | Y | -- | -- | -- | Y | Y | -- | -- | Y | -- | -- | -- |
| Hashable | Y | -- | -- | -- | Y | Y | -- | -- | Y | -- | -- | -- |
| Sequence | Y | Y | -- | -- | Y | Y | -- | -- | Y | Y | -- | -- |
| Collection | Y | -- | -- | -- | -- | -- | -- | -- | Y | Y | -- | -- |
| Input.Protocol | Y | Y | Y | Y | -- | -- | -- | -- | -- | -- | -- | -- |
| Sendable | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |

Legend: Y = present, -- = absent, DE = DoubleEnded

## Outcome

**Status**: RECOMMENDATION

The package provides complete canonical queue ADT coverage. All 12 type variants implement the five core FIFO operations (or six core deque operations for DoubleEnded variants). The API design is consistent across variants with appropriate adaptations for storage constraints (typed throws on bounded variants, dual peek API for ~Copyable support).

The primary gaps are in algebraic conformances (`Equatable`/`Hashable`) on Fixed, Static, Small, and DoubleEnded sub-variants. These are additive improvements that do not affect functional completeness. The `Equatable`/`Hashable` gap is the most significant because capacity-independent element-wise comparison is a core queue semantic -- if two queues contain the same elements in the same FIFO order, they are equal regardless of their storage strategy. This should be addressed for consistency with Queue (Dynamic) and Queue.Linked, which already have these conformances.

No operations from the canonical Queue ADT are missing from any variant. The package is functionally complete for Layer 1 primitives.

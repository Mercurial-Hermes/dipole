# TS2-001 — First Semantic Projection  
## Event Kind Classification

---

## Architectural Role

TS2-001 introduces the **first interpretive semantic layer** above the event log.

It establishes that:

- meaning can be derived from immutable truth
- meaning is replayable and deterministic
- meaning is non-authoritative and downstream-only
- semantic interpretation does not leak back into execution

This is the **minimum viable semantic projection**.

---

## Anchors

- semantic derivation  
- projection purity  
- replay determinism  
- downstream-only interpretation  

---

## Types Touched

- `Event`  
- `DebugSession`  
- `projection.zig` (or equivalent semantic module)

> ⚠️ No new runtime, registry, planner, or subscriber types are introduced.

---

## Explicit Non-Dependencies

This projection must have **no dependency** on:

- controller  
- driver  
- repl  
- tmux  
- kernel / lldb  
- wall-clock time  
- external IO  
- global or mutable state  

---

## Semantic Object Introduced

```zig
pub const EventKind = enum {
    SessionLifecycle,
    UserAction,
    EngineActivity,
    Snapshot,
    Unknown,
};
```

Notes:
- EventKind is semantic, not structural.
- It carries no authority and introduces no behaviour.
- It does not exist in TS1 and must not contaminate TS1 concepts.

## Projection Contract
### Illustrative Signature
```zig
pub fn projectEventKinds(
    alloc: std.mem.Allocator,
    events: []const Event,
) ![]EventKind
```

Allocator is injected.
Caller owns and must free the returned slice.

## Required Properties

1. Totality
- Exactly **one** `EventKind` **is produced per input** `Event`
- Output length must equal input length

This explicitly forbids filtering or aggregation.

2. Ordering Preservation

- Output ordering corresponds **exactly** to the input event order
- The projection must not reorder, sort, or group events
- Index `i` in the derived slice corresponds to index `i`in the event log

Ordering is inherited, not recomputed.

3. Determinism
- Identical event logs must produce identical derived results
- Replay of a persisted event log must yield byte-identical output
- No randomness, hashing, or address-based behaviour is permitted

4. Input Scope Restriction
The projection **may depend only on**:
- `Event.category`
- `Event.event_id` (identity only)

The projection **must not depend on**:
- timestamps
- wall-clock or monotonic time
- heap addresses
- payload contents
- debugger replies
- command intent
- previously derived semantic state
- global variables or caches

This is a hard semantic firewall.

5. Purity
- Read-only over immutable event log
- No mutation of `DebugSession`
- No side effects
- No IO
- No caching across invocations

Calling the projection multiple times must be observationally equivalent.

6. Lossiness (Intentional)
- Multiple distinct events may map to the same `EventKind`
- No attempt is made to preserve full event identity or payload meaning
- Loss of information is expected and required

## Behavioural Tests

### Test 1 — Classification Exists

**Given**
A `DebugSession` containing `N` events

**When**
The semantic projection is applied

**Then**
- The derived result contains exactly `N` `EventKind` values
- No element is missing or uninitialised

### Test 2 — Length Preservation

**Assertion**

`derived.len == events.len`

Filtering, collapsing, or skipping events is forbidden.

### Test 3 — Ordering Preservation

**Given**
- An event log with a known, non-trivial order
- The events appear in a known, non-trivial order

**When**

A semantic projection is applied to the event log

**Then**
- The derived output index `i` corresponds exactly to the event at index `i`
- The projection performs **no sorting, grouping, or reordering**
- Ordering is inherited from the event log, not recomputed from `event_id`

> Important: the projection may observe `event_id`, but must not use it to reorder.

### Test 4 — Replay Determinism

**Given**
- An event log `L`
- A replayed log `L′` reconstructed from `L`such that:
  - categories are identical
  - event_id values are identical
  - slice ordering is identical
    allocation and object identity may differ

**When**
- `projectEventKinds` is applied independently to `L` and `L′`

**Then**
`projectEventKinds(L) == projectEventKinds(L′)`

Where equality is:
- same length
- same `EventKind` at each index

Semantic meaning must be replay-equivalent.

### Test 5 — Input Field Isolation

**Given**
- Two event logs identical in:
  - `Event.category`
  - `Event.event_id`
  - slice ordering
- But differing in all other fields
  (timestamps, payloads, metadata, auxiliary data)

**When**
- A semantic projection is applied to both logs

**Then**
- The derived semantic outputs must be identical
- Equality is defined as:
  - same length
  - same `EventKind` at each index

This test enforces that semantic meaning depends **only** on explicitly
permitted fields and is isolated from all incidental or future data.
This constraint is non-negotiable.

## TS2-001 intentionally does not specify:
- projection identity or naming
- projection registry or hosting
- subscriber delivery mechanisms
- command planning or debugger interaction
- semantic state accumulation
- composition of multiple projections

Those concerns are deferred to later TS2 work.

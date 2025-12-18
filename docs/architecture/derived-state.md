# Derived State Model

## Purpose

The **Derived State Model** defines all state in Dipole that is *not* immutable truth.

Derived state exists to support interaction, inspection, and understanding, but it is never authoritative.  
It may be rebuilt, discarded, or recomputed at any time.

This model prevents hidden mutation and preserves the integrity of the event-sourced core.

---

## Core Definition

**Derived State** is any data that is computed from:
- events
- snapshots
- replay position
- user selection

Derived state:
- is ephemeral
- is reconstructible
- is not persisted as truth
- must never influence event history

---

## Design Principle

> **If it can be rebuilt from events and snapshots, it must not be stored as truth.**

This rule is load-bearing.

---

## What Counts as Derived State

Derived state includes (but is not limited to):

- current thread selection
- current frame selection
- current replay position
- visible register set
- visible call stack
- visible locals
- active memory view
- disassembly views
- symbol resolution caches
- source mapping caches

None of these are immutable facts.

---

## Disassembly as Derived State

Disassembly is a **derived artifact**, not an event or snapshot.

Characteristics:
- address-indexed
- binary-dependent
- time-independent
- cacheable
- discardable

Disassembly:
- contextualises instruction pointers
- supports understanding
- does not represent historical change

It must never be recorded as an event.

---

## Derived State vs Snapshots

Snapshots:
- capture observed execution state
- are immutable
- represent historical truth

Derived state:
- presents a view over snapshots and events
- changes freely as the user navigates
- has no historical meaning

Snapshots anchor understanding.  
Derived state enables interaction.

---

## Live vs Recorded Sessions

### Live Sessions
- derived state updates as new events arrive
- projections must tolerate incomplete information
- loss of derived state must not affect execution

### Recorded Sessions
- derived state follows replay position
- projections are deterministic
- derived state may be navigated arbitrarily

In both cases, derived state is disposable.

---

## Caching and Performance

Derived state may be cached aggressively for performance.

However:
- caches must be invalidatable
- cache loss must be harmless
- cache correctness must not affect truth

Performance optimisations must never leak into the core model.

---

## Forbidden Practices (Explicit)

The following are **not allowed**:

- mutating snapshots
- emitting events to “fix” derived state
- persisting derived state as authoritative data
- embedding derived state into event payloads

Violations undermine replay, pedagogy, and correctness.

---

## Relationship to Other Core Models

- **Event Model**  
  Derived state is computed *from* events.

- **Snapshot Model**  
  Derived state is projected *over* snapshots.

- **Semantic Derivation**  
  Meaning is layered on top of derived state without mutation.

- **Execution Source**  
  Derived state must not influence event emission.

---

## Pedagogical Implications

By keeping derived state ephemeral:

- learners can explore safely
- multiple views can coexist
- explanations remain flexible
- history remains trustworthy

Understanding becomes additive, not fragile.

---

## Summary

Derived state is the **lens**, not the **record**.

It exists to help humans navigate and understand debugging realities,  
while preserving a clean separation between:
- immutable truth, and
- mutable interaction.

This separation is essential to Dipole’s architecture and mission.

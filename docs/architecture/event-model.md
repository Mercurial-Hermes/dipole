# Dipole Event Model

## Purpose

The Dipole **Event Model** defines the immutable data contract that underpins all Debug Sessions.

Events are the **only source of truth** in Dipole.  
All state, snapshots, explanations, and UI projections are *derived* from events.

If the event model is correct, the system remains understandable forever.

---

## Core Principle

> **Nothing happens in a Debug Session unless it is represented as an event.**

There is:
- no hidden state
- no implicit mutation
- no backend-specific shortcuts

---

## Event Sourcing in Dipole

Dipole adopts a strict **event-sourced architecture**.

- Events are **append-only**
- Events are **immutable**
- Events are **ordered**
- Events are **self-describing**

State is a *projection*, not a store.

---

## Event Categories

All events fall into one of five categories.

1. Session
2. Command
3. Backend
4. Execution
5. Snapshot

This taxonomy is stable and intentional.

---

## 1. Session Events

Session events describe lifecycle transitions.

Examples:
- session created
- backend attached
- session terminated

These events establish *context*.

Session events do **not** describe program execution.

---

## 2. Command Events

Command events represent **human or system intent**.

They answer:
> “What was asked of the debugger?”

Examples:
- set breakpoint
- step instruction
- continue execution
- request snapshot

Key properties:
- command intent is preserved
- backend expansion is *not* the event’s concern

This distinction is critical for pedagogy.

---

## 3. Backend Events

Backend events capture **observable debugger output**.

They answer:
> “What did the debugger report?”

Examples:
- textual output
- error responses
- acknowledgements
- asynchronous notifications

Backend events are **opaque** at capture time.

Interpretation happens later.

---

## 4. Execution Events

Execution events represent **semantic execution changes**.

They answer:
> “What actually happened to the program?”

Examples:
- process started
- process stopped
- breakpoint hit
- signal received
- thread created or exited

Execution events are backend-agnostic *interpretations* of backend output.

---

## 5. Snapshot Events

Snapshot events represent **intentional state capture**.

They answer:
> “What was the program state at this moment?”

Snapshots may include:
- registers
- call stack
- locals
- selected memory regions

Snapshots are immutable and self-contained.

They are not continuously streamed.

---

## Event Structure (Conceptual)

All events share a minimal common structure:

- event id
- session id
- timestamp
- event type
- payload

Payloads are type-specific and versioned.

---

## Ordering and Time

Event order is **authoritative**.

- Timestamps are informative
- Ordering defines causality
- Replays follow event order, not wall-clock time

In recorded sessions, ordering is exact.  
In live sessions, ordering reflects observation.

---

## What Is *Not* an Event

To preserve clarity, the following are **explicitly excluded**:

- derived state (threads list, selected frame)
- UI interactions
- formatting decisions
- explanations
- annotations
- diffs

These are all *projections* or *derivatives*.

---

## Relationship to Snapshots

Snapshots are events — not state.

They:
- occur at meaningful moments
- preserve historical truth
- enable replay and comparison

State reconstruction must never depend on mutable snapshot storage.

---

## Pedagogical Consequences

Because events are immutable:

- sessions can be replayed deterministically
- explanations can evolve independently
- multiple interpretations can coexist
- teaching does not require live binaries

This is foundational to Dipole’s educational mission.

---

## Design Constraint (Non-Negotiable)

> No Dipole module may mutate session state directly.

Modules may only:
- emit events
- request snapshots
- derive projections

Violating this rule breaks replay, pedagogy, and long-term maintainability.

---

## Summary

The Event Model is the **spine of Dipole**.

If an idea cannot be expressed as an event, it does not belong in the core.

Everything else — state, UI, lessons, explanations — is built *on top of* this immutable foundation.

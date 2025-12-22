# Dipole Debug Session Model

## Purpose

The **Debug Session** is the foundational concept in Dipole.

A Debug Session represents a *debugging reality* — a structured, inspectable record of how a program was observed, interrogated, and understood, either **live** via a debugger backend or **offline** via a captured dataset.

Everything in Dipole projects from this model.

---

## Core Definition

A **Debug Session** is an immutable, event-sourced model of a debugging interaction, from which all state, explanation, and presentation are derived.

A session is:
- stateful (in meaning)
- immutable (in storage)
- replayable (in pedagogy)
- backend-agnostic (live or recorded)

---

## Non-Goals (Explicit)

A Debug Session does **not** attempt to:

- reverse arbitrary program execution
- simulate or resume execution from historical state
- guarantee determinism across live runs
- replace a native debugger

Dipole preserves **understanding**, not execution control.

---

## Session Modes

A Debug Session may operate in one of two modes.

### 1. Live Debug Session

- Backed by a debugger (e.g. LLDB)
- Events are emitted in real time
- Snapshots are captured selectively
- Used for:
  - real debugging
  - exploration
  - diagnosis

### 2. Recorded Debug Session (Dataset-Backed)

- No live process
- Events and snapshots are replayed from an immutable dataset
- Fully deterministic *within the recorded scope*
- Used for:
  - teaching
  - lessons
  - guided walkthroughs
  - comparative analysis

Both modes share **the same session model**.

---

## Architectural Invariants

These rules are load-bearing and non-negotiable.

### Invariant 1 — Immutability

Once recorded, session data is never mutated.

- Events are append-only
- Snapshots are immutable
- Explanations are additive

Any derived state must be reconstructible from source data.

---

### Invariant 2 — Event Sourcing

All meaningful changes in a session are represented as **events**.

There is no hidden or implicit state mutation.

State is a *projection*, not a source of truth.

Dipole records a total, immutable order of observed events.
This order is authoritative even when multiple events occur simultaneously in physical time.

---

### Invariant 3 — Backend Independence

The session model does not depend on:
- LLDB
- PTYs
- terminals
- UI frameworks

Backends emit events.  
Sessions interpret them.

---

### Invariant 4 — Semantic First

The purpose of a session is not to mirror debugger output verbatim, but to model **meaningful program behaviour**.

Examples:
- why execution stopped
- what changed since the last stop
- what matters to a learner

---

## Core Responsibilities of a Debug Session

A Debug Session is responsible for:

1. **Lifecycle Modeling**
   - created
   - attached
   - running
   - stopped
   - terminated

2. **Event Recording**
   - commands issued
   - backend responses
   - stop reasons
   - snapshot capture events

3. **State Derivation**
   - threads
   - frames
   - registers
   - symbols
   - breakpoints

4. **Snapshot Management**
   - capture at semantic moments
   - preserve historical states
   - enable comparison and replay

5. **Semantic Derivation**
   - identify deltas
   - attach causal explanations
   - support pedagogy

---

## What a Debug Session Is *Not*

A Debug Session is **not**:

- a transport layer
- a UI controller
- a storage engine
- a lesson renderer
- a debugger driver

Those are separate concerns that *consume* the session.

---

## Pedagogical Implications

Because the session is immutable and replayable:

- lessons can be built from recorded sessions
- learners can rewind and inspect causality
- explanations can evolve independently of binaries
- complex behaviour can be taught without live execution

This is a primary value proposition of Dipole.

---

## Design Consequence

Because the Debug Session is the heart of Dipole:

No core module may directly mutate session state.

All mutation must occur as:
- emitted events
- captured snapshots
- derived projections

This constraint enables replay, auditability, and long-term architectural sanity.

---

## Summary

The Debug Session is the **unit of meaning** in Dipole.

Whether live or recorded, it represents:
- what happened
- why it mattered
- how it can be understood

Everything else in Dipole exists to:
create sessions, project sessions, or learn from sessions.

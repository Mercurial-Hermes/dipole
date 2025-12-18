# Execution Source Model

## Purpose

The **Execution Source** defines where a Debug Session’s events originate.

It abstracts over *live* and *recorded* debugging realities, allowing the rest of Dipole to operate against a single, unified session model without special-casing.

An Execution Source is a **producer of events**, not an interpreter of meaning.

---

## Core Definition

An **Execution Source** is a component that emits an ordered stream of immutable events representing observed debugging activity.

It may represent:
- a live debugger attached to a running process, or
- a finite, recorded dataset captured previously

The Debug Session consumes events identically in both cases.

---

## Design Principle

> **The Debug Session does not know whether it is live or recorded.  
> Only the Execution Source knows.**

This separation is foundational.

---

## Responsibilities

An Execution Source is responsible for:

1. **Event Emission**
   - produce ordered session events
   - preserve causal ordering
   - never mutate or reinterpret past events

2. **Session Boundaries**
   - signal when a session begins
   - signal when no further events will occur (if finite)

3. **Capability Disclosure**
   - whether execution can continue
   - whether stepping is meaningful
   - whether replay boundaries exist

The Execution Source does **not**:
- derive state
- interpret semantics
- generate explanations
- manage snapshots directly

---

## Types of Execution Sources

Dipole defines two primary Execution Source types.

### 1. Live Execution Source

A Live Execution Source is backed by a real debugger (e.g. LLDB).

Characteristics:
- events are emitted asynchronously
- the event stream is open-ended
- execution control commands are meaningful
- ordering reflects observation, not determinism

Use cases:
- real-world debugging
- exploratory investigation
- interactive REPL-driven workflows

---

### 2. Recorded Execution Source

A Recorded Execution Source is backed by an immutable dataset.

Characteristics:
- events are finite and pre-recorded
- ordering is exact and deterministic
- no live execution control exists
- replay boundaries are explicit

Use cases:
- pedagogy
- lessons
- guided walkthroughs
- comparative analysis

---

## Execution Control Semantics

Execution control commands (e.g. continue, step) are **requests**, not guarantees.

- In a Live Execution Source:
  - control requests are forwarded to the debugger backend
  - resulting behaviour is observed via emitted events

- In a Recorded Execution Source:
  - control requests advance replay position
  - behaviour is constrained to recorded bounds

The Debug Session issues the same commands in both cases.

---

## Finite vs Infinite Sources

Execution Sources declare whether their event stream is:

- **Infinite** (live debugging)
- **Finite** (recorded sessions)

This allows:
- UIs to render progress appropriately
- sessions to terminate cleanly
- replay semantics to remain honest

---

## Failure and Error Reporting

Execution Sources may emit events representing:
- backend errors
- transport failures
- dataset corruption
- unsupported operations

Errors are **events**, not exceptions.

This preserves auditability and replay.

---

## Architectural Constraints (Non-Negotiable)

The following rules must never be violated:

1. Execution Sources must never derive meaning  
2. Execution Sources must never mutate session state  
3. Execution Sources must never emit synthetic events to “help” the model  

They report what happened — nothing more.

---

## Relationship to Other Core Objects

- **Debug Session**  
  Consumes events emitted by the Execution Source.

- **Event Model**  
  Defines the schema of emitted events.

- **Snapshot Model**  
  Snapshots are requested by the session, not initiated by the source.

- **Dataset Model**  
  A Recorded Execution Source is constructed from a dataset.

---

## Summary

The Execution Source is the **boundary between reality and understanding**.

By isolating event production from interpretation, Dipole supports both:
- live, REPL-driven debugging, and
- deterministic, replayable pedagogical sessions

using the same core architecture.

This abstraction is essential to Dipole’s long-term clarity and power.

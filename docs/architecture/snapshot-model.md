# Snapshot Model

## Purpose

The **Snapshot Model** defines how Dipole captures and represents program state at defined moments during a Debug Session.

Snapshots preserve *observed truth* at a point in time.  
They enable comparison, replay, and pedagogy — without attempting to rewind or resume execution.

Snapshots are **explicit**, **immutable**, and **intentional**.

---

## Core Definition

A **Snapshot** is an immutable capture of selected program state taken at a specific moment in a Debug Session.

Snapshots:
- are created deliberately
- represent observation, not simulation
- never change once recorded
- may be replayed indefinitely

Snapshots are **events**, not mutable state.

---

## Design Principle

> **Snapshots capture state only at defined moments.  
> Continuous capture is explicitly rejected.**

This preserves clarity, performance, and pedagogical value.

---

## When Snapshots Occur

Snapshots are captured at defined moments, such as:

- breakpoint hit
- step completion
- function entry or exit
- signal delivery
- user-requested capture

Snapshots must never be taken implicitly “just in case”.

---

## Snapshot Scope

Snapshots capture a **bounded view** of program state.

A snapshot may include:

- register state
- call stack (frames)
- local variables
- arguments
- selected memory regions
- instruction pointer and symbols

A snapshot does **not** imply:
- full process memory capture
- OS-level state preservation
- reversibility of execution

Scope is always explicit.

---

## Snapshot Intent

Every snapshot has a **reason** that identifies its capture boundary.

Examples:
- breakpoint hit
- step complete
- user-requested capture

This intent is preserved as capture metadata and supports replay.

---

## Snapshot Granularity

Dipole supports multiple snapshot granularities:

### Minimal
- PC
- selected thread/frame
- stop reason

### Standard
- registers
- call stack
- locals

### Extended (Explicit, Opt-In)
- selected memory regions
- additional thread state

Granularity is a policy decision, not a structural one.

---

## Snapshot Immutability

Once recorded:

- snapshots are never mutated
- snapshots are never “updated”
- snapshots are never merged

Corrections or reinterpretations must be additive and external.

This guarantees:
- replay fidelity
- auditability
- pedagogical trust

---

## Snapshots vs State

Snapshots are **not state**.

They:
- do not define the “current” program state
- do not replace derived session projections
- do not accumulate implicitly

State is always derived from:
- events
- selected snapshots
- replay position

---

## Relationship to Events

Snapshots are represented as **Snapshot Events** in the event log.

They:
- have a position in event order
- reference captured data
- carry capture metadata

Snapshot payloads are raw observational artifacts.  
Parsing and interpretation are strictly downstream in projections.

---

## Live vs Recorded Sessions

### Live Sessions
- snapshots are captured opportunistically
- capture cost must be considered
- snapshot failure must not block execution

### Recorded Sessions
- snapshots are authoritative
- replay relies on snapshot boundaries
- stepping is constrained to snapshot intervals

Both use the same snapshot model.

---

## Pedagogical Consequences

Because snapshots are intentional and immutable:

- learners can safely rewind
- experts can annotate precisely
- explanations can evolve independently
- complex behaviour can be taught deterministically

Snapshots are stable anchors for downstream explanation.

---

## Architectural Constraints (Non-Negotiable)

1. Snapshots must never be implicit  
2. Snapshots must never mutate state  
3. Snapshots must never attempt reversibility  
4. Snapshots must always be attributable to a capture boundary  

Violating these rules undermines the entire model.

---

## Summary

Snapshots are **frozen observations** of program reality.

They trade completeness for clarity,  
and control for understanding.

By capturing only what matters — when it matters —  
Dipole enables replayable insight without false promises of reversibility.

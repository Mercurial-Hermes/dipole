# Minimal Type Graph

## Purpose

This document defines the **minimal set of core types** in Dipole and the **allowed relationships** between them.

It exists to:
- provide a shared vocabulary for implementation discussions
- constrain future API and module design
- prevent accidental coupling across architectural boundaries

This is **not** a data schema and **not** an API specification.

Types are listed by *conceptual role only*.

---

## Design Principle

> **Names first, structure later, behaviour last.**

If a type does not appear here, it does not belong in the core.

---

## Core Types (Canonical)

These are the **irreducible nouns** of Dipole.

1. DebugSession
2. ExecutionSource
3. Event
4. Snapshot
5. Dataset
6. DerivedState
7. SemanticAnnotation


Everything else is built *around* or *on top of* these.

---

## Type Responsibilities (One Line Each)

### DebugSession
Owns session identity, event ordering, and replay position.  
Consumes events; never produces meaning.

---

### ExecutionSource
Produces ordered events from an external reality.  
Knows whether the session is live or recorded.

---

### Event
An immutable record that *something happened*.  
Authoritative historical truth.

---

### Snapshot
An immutable capture of selected execution state at a meaningful moment.  
Anchors replay and comparison.

---

### Dataset
A durable container for events, snapshots, and optional annotations.  
Backs recorded execution sources.

---

### DerivedState
Ephemeral, reconstructible projections over events and snapshots.  
Supports interaction and navigation.

---

### SemanticAnnotation
Derived explanations and pedagogical meaning.  
Never alters truth; may evolve independently.

---

## Allowed Relationships (Directed)

Arrows indicate **allowed knowledge / dependency**, not ownership.

ExecutionSource ─────▶ Event
│
▼
DebugSession
│
┌─────────────┴──────────── ──┐
▼                             ▼      
Snapshot                DerivedState
│
▼
SemanticAnnotation


---

## Note on Controller and Event Ingress

The Controller does not appear in the minimal type graph by design.

The graph describes *conceptual ownership of truth*, not the mechanics of interaction.
In particular:

- **ExecutionSource defines what kinds of Events may be emitted**
  (their schema, ordering guarantees, and authority as truth).
- **The Controller defines when and why interaction with an ExecutionSource occurs**.

In live debugging, the Controller may perform transport-level interaction
(e.g. sending commands, observing raw I/O) on behalf of an ExecutionSource.
However, the resulting observations are still considered events *of that ExecutionSource*.

The Controller:
- does not define event meaning
- does not invent or reinterpret events
- does not own event validity
- does not participate in derived state or semantics

Its role is strictly to orchestrate interaction and act as the ingress boundary
through which externally observed events enter the DebugSession.

For this reason, the Controller is intentionally excluded from the minimal type graph.

---

## Relationship Rules (Explicit)

### ExecutionSource
- emits `Event`
- does **not** know about:
  - DebugSession internals
  - DerivedState
  - Semantics

---

### DebugSession
- consumes `Event`
- orders events
- references `Snapshot`
- does **not** depend on:
  - ExecutionSource implementation
  - DerivedState
  - SemanticAnnotation

---

### Snapshot
- is referenced by `DebugSession`
- is derived from events at capture time
- does **not** reference:
  - DerivedState
  - SemanticAnnotation

---

### Dataset
- contains `Event`
- contains `Snapshot`
- may contain `SemanticAnnotation`
- never contains `DerivedState`

---

### DerivedState
- is computed from:
  - DebugSession
  - Event
  - Snapshot
- may reference disassembly, symbols, caches
- must be fully reconstructible

---

### SemanticAnnotation
- may reference:
  - Event
  - Snapshot
- may consume DerivedState as input
- must never mutate or replace truth

---

## Forbidden Relationships (Non-Negotiable)

The following dependencies are **explicitly disallowed**:

- Event → DerivedState
- Event → SemanticAnnotation
- Snapshot → DerivedState
- Snapshot → SemanticAnnotation
- SemanticAnnotation → Event
- DerivedState → Event
- Dataset → DerivedState
- Kernel types → ExecutionSource implementations

Violating these collapses the architecture.

---

## Notes on Disassembly

Disassembly:
- is not a core type
- lives within DerivedState / DerivedArtifacts
- is address-indexed, cacheable, discardable
- must never appear in Event, Snapshot, or Dataset

---

## Why This Graph Is Minimal

Each type here exists because at least one of the following is true:

- it represents immutable truth
- it represents an execution boundary
- it represents pedagogical meaning
- it prevents architectural leakage

If a proposed type cannot be placed on this graph cleanly, it does not belong in the core.

---

## Summary

This minimal type graph defines the **load-bearing structure** of Dipole.

It ensures:
- a small, defensible kernel
- clear dependency direction
- clean separation between truth, interaction, and meaning

All future structures and APIs must be explainable in terms of these types and relationships.

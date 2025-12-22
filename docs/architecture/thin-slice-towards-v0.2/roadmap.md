# Thin Slice Roadmap — Dipole v0.2.0

This document tracks the **thin-slice iteration plan** for Dipole v0.2.  
Each slice answers **one architectural question**, introduces **one new kind of structure**, and then stops.

The goal is not speed, but **irreversibility**: once a slice lands, its invariants are locked by tests and artifacts.

---

## Guiding Principles

- One conceptual question per slice
- Semantic layers before execution
- Meaning before intent, intent before authority
- Downstream-only dataflow until the execution membrane
- Tests lock *shape*, not convenience
- No slice retrofits invariants from earlier slices

---

## Completed Slices

### TS2-001 — First Semantic Projection
**Status:** ✅ Passed

- Proved that semantic meaning can be derived from the event log
- Established purity, replay determinism, ordering inheritance
- Introduced first semantic object (`EventKind`)

---

### TS2-002 — Projection Identity & Registry
**Status:** ✅ Passed

- Introduced stable identity for semantic meaning
- Established declarative, inert projection registry
- Locked unambiguous naming and explicit version coexistence
- Required explicit declaration of semantic dependency surfaces
- Registry is non-operational by construction

---

## Remaining Slices to v0.2

---

## TS2-003 — Projection Contract Drift

**Core question:**  
How do we prove that projection implementations respect the dependency surfaces they declare?

**Introduces:**
- Contract drift tests for all registered projections
- Synthetic event-pair tests proving non-dependence on forbidden fields (per projection)

**Key invariants:**
- Declared `permitted_fields` are semantically enforced
- Changing non-permitted fields does not affect outputs
- No runtime instrumentation or execution hooks

**Explicitly excludes:**
- Runtime enforcement
- Code scanning
- Reflection or instrumentation in production code

---

## TS3-001 — First Consumer Boundary (CLI)

**Core question:**  
How is semantic meaning consumed without authority or control flow?

**Introduces:**
- CLI consumer for semantic meaning:
  - `semantic list`
  - `semantic show <ProjectionId>`
- Explicit consumer opt-in to projection version

**Key invariants:**
- Consumers reference meaning **by `ProjectionId` only**
- No fallback to “latest” projection version
- Consumption is read-only and downstream-only

**Explicitly excludes:**
- Planner logic
- UI frameworks
- Execution or command issuing

---

## TS3-010 — Projection Feed (Pub/Sub)

**Core question:**  
How do we distribute semantic meaning deterministically to multiple consumers?

**Introduces:**
- Downstream-only projection feed
- Publishing **projection frames** keyed by `ProjectionId`
- Replay-deterministic feed rebuildable from the event log (same log → same frames)

**Key invariants:**
- No raw event subscriptions
- No mutation or execution
- Feed output is derived meaning only

**Primary consumers:**
- CLI
- REPL
- tmux panes (later slice)

---

## TS3-UI-001 — REPL & tmux Reintroduction (Read-Only)

**Core question:**  
How do we reintroduce UI surfaces without reintroducing authority?

**Introduces:**
- REPL and tmux panes as **read-only consumers** of the projection feed
- Live semantic views derived from projections

**Key invariants:**
- UI does not mutate state
- UI does not execute commands (any future command input must flow through the controller ingress)
- UI observes projections, not raw events

**Explicitly excludes:**
- Command issuing
- Planner integration
- Execution control

---

## TS4-001 — Execution Membrane

**Core question:**  
Where does authority finally enter the system, and how is it contained?

**Introduces:**
- Controller / Driver / PTY integration
- Execution as a narrow membrane
- Transport observations appended as events

**Key invariants:**
- Event log append is the sole ingest path
- Failures become explicit events
- Projections remain pure and replayable
- Execution failures do not contaminate semantics

**Outcome:**
- End-to-end loop: execution → events → meaning → observation

---

## v0.2 Definition of “Done”

Dipole v0.2 is considered complete when:

- REPL and tmux panes display live semantic views
- Projection feed distributes meaning deterministically
- Execution is reattached via a single authority membrane
- All semantic layers remain pure and replay-stable
- Event sourcing invariants hold end-to-end

---

## Notes on Scope Discipline

- Naming convention enforcement is folded into TS2-003 if needed
- No slice introduces both meaning and authority
- UI and execution are intentionally separated
- Each slice ends with a `.md` summary and merge milestone

---

## Summary

This roadmap preserves the cadence established in TS2:

> **truth → meaning → distribution → observation → intent → authority**

Each thin slice makes one irreversible move forward, ensuring Dipole v0.2
is not just functional, but *architecturally legible and teachable*.

# Dataset Model (Debug Capture Dataset)

## Purpose

The **Dataset Model** defines how Dipole represents a recorded debugging reality as a durable, portable artifact.

A **Debug Capture Dataset (DCD)** enables:
- deterministic replay
- pedagogy without live binaries
- sharing of debugging insight
- long-term preservation of understanding

Datasets are the bridge between *live debugging* and *teaching*.

---

## Core Definition

A **Debug Capture Dataset** is an immutable collection of:
- session metadata
- ordered events
- captured snapshots
- optional semantic annotations

A dataset represents *what was observed*, not *what could be re-executed*.

---

## Design Principle

> **A dataset captures truth once, and enables understanding forever.**

Datasets are:
- immutable
- self-describing
- replayable
- independent of execution

---

## What a Dataset Contains

A dataset contains the following components.

### 1. Dataset Metadata

Metadata describes the capture context.

Examples:
- dataset identifier
- capture time
- architecture and platform
- debugger backend used
- binary identity (hashes, paths, build info)
- capture scope and intent (lesson, investigation, demo)

Metadata is informational and non-authoritative.

---

### 2. Event Log

The event log is the **authoritative historical record**.

- ordered
- append-only
- immutable
- conforms to the Event Model

The event log defines the session timeline.

---

### 3. Snapshots

Snapshots are immutable state captures recorded as snapshot events.

- intentional
- bounded in scope
- attributable to semantic moments

Snapshots anchor replay and comparison.

---

### 4. Optional Semantic Annotations

Datasets may include semantic annotations.

Annotations:
- attach to events or snapshots
- never modify truth
- may be layered or versioned
- may be human-authored or tool-generated

Annotations are optional but central to pedagogy.

---

## What a Dataset Does *Not* Contain

To preserve clarity and integrity, datasets must never contain:

- derived state
- UI state
- disassembly caches
- transient debugger output
- replay position
- mutable projections

Anything reconstructible must remain reconstructible.

---

## Dataset Immutability

Once created:
- datasets are never mutated
- corrections are additive
- reinterpretation does not alter source data

New understanding produces *new annotations*, not new truth.

---

## Dataset Completeness

Datasets may be:
- minimal (events only)
- snapshot-rich
- pedagogy-focused

Completeness is a capture-time decision.

Dipole must tolerate:
- partial datasets
- incomplete snapshots
- missing semantic layers

---

## Live Capture vs Dataset Construction

### Live Capture

During a live session:
- events are streamed
- snapshots are captured opportunistically
- semantics may be partial or absent

Live capture must never block execution.

---

### Dataset Construction

A dataset may be constructed:
- incrementally during a live session, or
- offline from previously captured material

Construction is separate from session execution.

---

## Dataset Replay

When used as an Execution Source:
- datasets emit events in recorded order
- replay is bounded and deterministic
- execution control is constrained to recorded scope

Replay simulates *observation*, not *execution*.

---

## Pedagogical Use

Datasets enable:

- lesson-driven replay
- expert walkthroughs
- side-by-side comparison
- safe exploration
- deterministic learning environments

They decouple teaching from tooling friction.

---

## Distribution and Sharing

Datasets are designed to be:
- portable
- shareable
- inspectable
- archivable

They may be distributed:
- with courses
- between learners
- as reference material

Privacy and security considerations are external concerns.

---

## Relationship to Other Core Models

- **Execution Source**  
  A dataset-backed Execution Source replays dataset events.

- **Event Model**  
  Defines dataset event structure.

- **Snapshot Model**  
  Defines snapshot contents and constraints.

- **Semantic Derivation**  
  Produces or consumes annotations layered on datasets.

- **Derived State**  
  Reconstructed dynamically during replay.

---

## Architectural Constraints (Non-Negotiable)

1. Datasets must never embed derived state  
2. Datasets must never embed UI concepts  
3. Datasets must never imply resumable execution  
4. Datasets must remain valid as semantics evolve  

Breaking these rules undermines trust and pedagogy.

---

## Summary

A Debug Capture Dataset is a **recorded debugging reality**.

It preserves:
- what happened
- what was observed
- what mattered

By separating immutable truth from evolving understanding,  
datasets allow Dipole to serve both:
- live debugging, and
- deep, replayable pedagogy

with the same core architecture.

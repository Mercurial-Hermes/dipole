# Dipole Module Boundary Map

## Purpose

This document defines the **conceptual module boundaries** within Dipole.

Its goal is to:
- establish clear separation of concerns
- prevent architectural drift
- provide a shared vocabulary for discussing design
- constrain future implementation decisions

This is a **boundary map**, not a directory layout or API specification.

---

## High-Level Architecture

Dipole is structured around a **small, protected kernel**, surrounded by interpretive layers and external reality adapters.

All dependencies flow in **one direction only**.


+--------------------------------------------------+
|                   UI / Dojo / CLI                |
|          (views, navigation, pedagogy)           |
+-----------------------↑--------------------------+
|              Semantic Derivation Layer            |
|         (explanations, annotations, meaning)      |
+-----------------------↑--------------------------+
|              Derived State & Artifacts            |
|    (threads, frames, disassembly, projections)    |
+-----------------------↑--------------------------+
|           Debug Session Core (KERNEL)             |
|   (events, snapshots, ordering, invariants)       |
+-----------------------↑--------------------------+
|              Execution Sources                    |
|   (Live Debugger | Recorded Dataset Replay)       |
+--------------------------------------------------+


Only upward dependencies are allowed.

---

## The Kernel: Debug Session Core

The **Debug Session Core** is the heart of Dipole.

It models immutable truth and enforces architectural invariants.

### Responsibilities

The kernel owns:
- Debug Session model
- Event Model
- Snapshot Model
- Dataset structural model
- ordering and immutability rules

### Constraints

The kernel must **not** know about:
- debugger backends (e.g. LLDB)
- terminals or UI frameworks
- disassembly or symbols
- pedagogy or explanations
- execution control semantics

The kernel models **what happened**, not **how it happened** or **what it means**.

This layer should remain small and aggressively defended.

---

## Execution Sources (Reality Boundary)

Execution Sources are the **only modules that interact with external reality**.

They adapt:
- live debugger backends, or
- recorded datasets

into a stream of immutable events.

### Types of Execution Sources

- **Live Execution Source**
  - backed by a real debugger (e.g. LLDB)
  - open-ended event stream
  - asynchronous observation

- **Recorded Execution Source**
  - backed by a Debug Capture Dataset
  - finite, deterministic event stream
  - replay-only semantics

### Dependency Rule

Execution Sources may depend on the kernel.  
The kernel must never depend on Execution Sources.

This prevents debugger-specific logic from polluting the core.

---

## Derived State & Artifacts

This layer exists to make Debug Sessions **usable and navigable**.

### Responsibilities

Derived State includes:
- current thread / frame selection
- replay position
- visible registers, stack, locals
- disassembly views
- symbol resolution caches
- source mapping caches

### Key Property

All derived state is:
- ephemeral
- reconstructible
- discardable

Deleting this entire layer must not affect correctness.

---

## Semantic Derivation Layer

This layer is where Dipole derives **meaning and explanation**.

### Responsibilities

Semantic Derivation produces:
- causal explanations
- register change narratives
- call/return interpretations
- pedagogical annotations
- architecture-aware reasoning

### Key Constraint

Semantics:
- must never mutate events or snapshots
- must never emit events
- may evolve independently of captures

Truth and interpretation must remain separate.

---

## UI / Tooling Layer

This layer includes all user-facing systems:

- CLI
- TUI (tmux)
- Dojo
- future native UIs

### Responsibilities

UI modules:
- navigate sessions
- render projections
- select replay positions
- surface semantics

### Constraints

UI must never:
- mutate kernel data
- emit events directly
- embed assumptions about execution sources

UI is a consumer of truth, not a producer.

---

## The Debugger’s Role (Clarification)

Talking to a debugger is **essential**, but the debugger is **not the kernel**.

The debugger is:
- an Execution Source
- a producer of events
- an adapter to external reality

The Debug Session Core remains the architectural centre.

This distinction enables:
- debugger-agnostic design
- dataset-backed pedagogy
- long-term maintainability

---

## Dependency Rules (Non-Negotiable)

1. The kernel depends on nothing
2. Execution Sources depend on the kernel
3. Derived State depends on kernel and sources
4. Semantic Derivation depends on kernel and derived state
5. UI depends on everything above it
6. No downward dependencies are allowed

Violating these rules introduces hidden coupling and architectural decay.

---

## Summary

This boundary map defines how Dipole remains:
- understandable
- extensible
- pedagogically powerful

By enforcing a small kernel, strict dependency direction, and clear separation between truth, interpretation, and presentation, Dipole can grow without losing coherence.

This document should be treated as a **design contract**, not a suggestion.

# Dipole Module Boundary Map

## Purpose

This document defines the **conceptual module boundaries** within Dipole.

Its goal is to:
- establish clear separation of concerns
- prevent architectural drift
- provide a shared vocabulary for discussing design
- constrain future implementation decisions

This is a **boundary map**, not a directory layout or API specification.

It is a **design contract**.

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
- the DebugSession model
- the Event model
- the Snapshot model
- dataset structural models
- ordering and immutability rules

### Constraints

The kernel must **not** know about:
- debugger backends (e.g. LLDB)
- terminals, PTYs, or UI frameworks
- CLI, REPL, or user input
- derived state or projections
- semantic interpretation or pedagogy
- execution control semantics

The kernel models **what happened**, not **how it happened** or **what it means**.

This layer must remain small and aggressively defended.

---

## Execution Sources (Reality Boundary)

Execution Sources are the **only modules that interact with external reality**.

They adapt:
- live debugger backends, or
- recorded datasets

into a stream of immutable observations.

### Types of Execution Sources

- **Live Execution Source**
  - backed by a real debugger (e.g. LLDB)
  - open-ended, asynchronous observation stream
  - nondeterministic timing

- **Recorded Execution Source**
  - backed by a Debug Capture Dataset
  - finite, deterministic observation stream
  - replay-only semantics

### Dependency Rule

Execution Sources may depend on the kernel.  
The kernel must never depend on Execution Sources.

Debugger-specific logic must never leak upward.

---

## Controller

The **Controller** is the **exclusive ingress boundary** between external execution and session truth.

It is not part of the kernel, not an execution source, and not a semantic layer.

It exists to **enforce ordering, exclusivity, and admission**.

### Does

The Controller:
- owns all debugger side effects
- owns the debugger transport (e.g. LLDB PTY) as a **single-reader / single-writer**
- routes user intent downward to execution sources
- admits externally observed effects upward as Events
- preserves a total, deterministic ordering of observations

### Does Not

The Controller does **not**:
- parse CLI arguments
- interpret debugger output
- derive semantic meaning
- store mutable state
- mutate DebugSession internals directly
- render UI or control presentation
- bypass the DebugSession

UI panes (REPL, tmux, Dojo) must never talk to LLDB directly.  
All debugger interaction flows **through the Controller**.

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

Deleting this entire layer must not affect correctness or truth.

---

## Semantic Derivation Layer

This layer is where Dipole derives **meaning and explanation**.

### Responsibilities

Semantic Derivation produces:
- causal explanations
- register change narratives
- call / return interpretations
- pedagogical annotations
- architecture-aware reasoning

### Key Constraint

Semantic logic:
- must never mutate events or snapshots
- must never emit events
- must never control execution
- may evolve independently of captures

Truth and interpretation must remain strictly separated.

---

## UI / Tooling Layer

This layer includes all user-facing systems:

- CLI
- TUI (tmux)
- Dojo
- future native UIs

### Responsibilities

UI modules:
- express user intent
- navigate sessions
- render projections
- surface semantic explanations

### Constraints

UI must never:
- mutate kernel data
- emit events directly
- read or write debugger transports
- embed assumptions about execution sources
- render raw LLDB output to the user

UI is a **consumer of truth**, not a producer.

---

## The Debugger’s Role (Clarification)

Talking to a debugger is **essential**, but the debugger is **not the kernel**.

The debugger is:
- an Execution Source
- a producer of observations
- an adapter to external reality

The Debug Session Core remains the architectural centre.

This distinction enables:
- debugger-agnostic design
- dataset-backed pedagogy
- replay and auditability
- long-term maintainability

---

## Dependency Rules (Non-Negotiable)

1. The kernel depends on nothing
2. Execution Sources depend on the kernel
3. Controllers depend on execution sources and the kernel
4. Derived State depends on the kernel and controllers
5. Semantic Derivation depends on kernel and derived state
6. UI depends on everything above it
7. No downward dependencies are allowed

Violating these rules introduces hidden coupling and architectural decay.

---

## Summary

This boundary map defines how Dipole remains:
- understandable
- extensible
- replayable
- pedagogically powerful

Any change that cannot be justified within this map is an architectural error.

This document should be treated as a **hard design contract**, not a suggestion.

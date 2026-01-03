# Interaction Flow

## Purpose

This document defines the **authoritative interaction flow** in Dipole, from user intent to visible outcome.

It exists to:
- clarify responsibility boundaries
- prevent logic leakage between layers
- provide a shared mental model for implementation
- constrain Controller and CLI behaviour

This is a **conceptual flow**, not an API or threading model.

---

## Core Principle

> **User intent flows downward.  
> Truth flows upward.  
> Meaning is layered on top.**

No layer violates this direction.

---

## High-Level Flow Overview

User
↓
CLI (session start) / Dipole REPL (commands)
↓
Controller
↓
ExecutionSource
↓
Event Stream
↓
DebugSession
↓
Derived State
↓
Semantic Derivation
↓
Rendering (tmux / REPL / Dojo)


Each arrow represents a **single responsibility handoff**.

---

## CLI & REPL Responsibility (Intent Boundary)

The CLI and REPL are responsible for:

- reading user input (argv, stdin)
- validating syntax
- expressing **intent**

The CLI / REPL:
- does not talk to the debugger
- does not own execution
- does not admit events
- does not interpret output

Its job ends once intent is handed to the Controller.

### Session Lifecycle (Live)

A live session follows a simple lifecycle:

start → interact → quit

- **start**: a single, long-lived LLDB process is launched/attached
- **interact**: the REPL is the sole command interface
- **quit**: the LLDB process is terminated and no further events occur

---

## Step-by-Step: Live Debugging Interaction

### Example: User types `step` in the REPL

---

### 1. User Input

The user enters a command:

`step`


This is **raw human input** with no backend semantics.

---

### 2. CLI / REPL: Intent Formation

The CLI:
- parses the input
- validates it
- expresses a **Command Intent**

Example (conceptual):

`CommandIntent.Step`


The CLI:
- does not know how stepping works
- does not know which debugger is used
- does not inspect session state

---

### 3. Controller: Intent Routing

The Controller receives the Command Intent.

Responsibilities:
- check session mode (live vs recorded)
- check execution source capabilities
- route intent downward

The Controller may:
- accept the intent
- reject it (unsupported)
- translate it into lower-level requests

The Controller does **not** interpret results.

---

## Controller Constraints (Non-Negotiable)

The Controller is a **side-effect and ingress boundary**, not an interpreter.

### The Controller MUST

- be the sole reader and writer of debugger transports
- forward intent to the ExecutionSource
- initiate external interaction
- capture **all externally observed effects**
- preserve exact observation order
- admit observations as immutable Events
- assign deterministic sequence identifiers

### The Controller MUST NOT

- parse debugger output
- recognise prompts or markers semantically
- infer execution state
- suppress or coalesce observations
- reorder events
- emit synthetic or “helpful” events
- mutate DebugSession internals
- update UI or derived state

Any such behaviour is an architectural violation.

---

## 4. ExecutionSource: External Interaction

For a **Live Execution Source**:
- Controller forwards intent
- debugger executes commands
- observations are produced

For a **Recorded Execution Source**:
- Controller advances replay
- observations are replayed

In both cases:

> The ExecutionSource **observes reality** and produces observations.

---

## 5. Event Emission

Observations are admitted as **Events**:

- immutable
- ordered
- authoritative
- backend-agnostic

No interpretation occurs here.

---

## 6. DebugSession: Truth Recording

The DebugSession:
- appends Events
- preserves total order
- provides immutable history

The DebugSession:
- does not interpret
- does not render
- does not control execution

It records truth — nothing else.

---

## 7. Snapshot Capture (Optional)

At defined moments:
- a Snapshot may be captured
- snapshot data is immutable
- snapshots are associated with Events

Snapshots are historical anchors.

---

## 8. Derived State Recalculation

Derived State is recalculated from:
- event history
- snapshots
- replay position

Derived State is:
- ephemeral
- reconstructible
- discardable

---

## 9. Semantic Derivation

Semantic Derivation:
- reads Events and Snapshots
- produces explanations and narratives
- never mutates truth

Semantics may be partial or provisional.

---

## 10. Rendering

UI components:
- read derived state / projections
- read semantic annotations when present
- render views

Rendering:
- does not emit events
- does not affect truth
- may refresh freely

Raw LLDB output is **never rendered directly** to the user.
It is preserved in the event log and logs only.

---

## Recorded Session Flow

Recorded sessions follow the **exact same flow**.

Only the ExecutionSource behaviour differs.

This symmetry is a core design goal.

---

## Error Handling

Errors are **Events**.

- debugger failures
- unsupported commands
- dataset corruption

Errors:
- are emitted upward
- recorded immutably
- rendered as feedback

Errors are never swallowed.

---

## What This Flow Explicitly Forbids

- UI talking directly to the debugger
- multiple readers of debugger transports
- Controller interpreting output
- CLI admitting events
- DebugSession inferring meaning
- Semantic logic mutating truth

Any shortcut breaks replayability and pedagogy.

---

## Mental Model Summary

- CLI expresses intent
- Controller enforces order
- ExecutionSource observes reality
- DebugSession records truth
- Derived State presents views
- Semantics explain meaning
- UI renders understanding

No shortcuts. No exceptions.

---

## Why This Matters

This flow ensures:
- live debugging stays responsive
- recorded sessions remain deterministic
- pedagogy is first-class
- architecture remains legible over time

If a change cannot be explained using this flow, it does not belong in the core.

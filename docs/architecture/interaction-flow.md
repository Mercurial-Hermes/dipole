# Interaction Flow

## Purpose

This document describes the **end-to-end interaction flow** in Dipole, from user intent to visible outcome.

It exists to:
- clarify responsibility boundaries
- prevent logic leakage between layers
- provide a shared mental model for implementation
- keep REPL, Controller, and Debugger roles clean

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
REPL / UI
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
Rendering (tmux / REPL output)


Each arrow represents a **single responsibility handoff**.

---

## Step-by-Step: Live Debugging Interaction

### Example: User types `step`

---

### 1. User Input

The user enters a command via the REPL:

- step


This is **raw human input**, with no backend semantics.

---

### 2. REPL: Intent Parsing

The REPL:
- parses the input
- validates syntax
- converts it into a **Command Intent**

Example (conceptual):

- CommandIntent.Step


The REPL:
- does not know how stepping works
- does not talk to the debugger
- does not inspect session internals

Its job ends here.

---

### 3. Controller: Intent Routing

The Controller receives the `CommandIntent`.

Responsibilities:
- check session mode (live vs recorded)
- check ExecutionSource capabilities
- route intent appropriately

The Controller may:
- accept the intent
- reject it (e.g. unsupported in replay)
- transform it into lower-level requests

The Controller does **not**:
- interpret debugger output
- mutate session state
- derive meaning

### Controller Constraints (Non-Negotiable)

The Controller is a **side-effect and ingress boundary**, not an interpreter.

Its responsibility is limited to routing intent downward and admitting
externally observed effects upward as Events.

#### The Controller MUST

- forward user intent to the appropriate ExecutionSource
- initiate external interaction (e.g. debugger commands, replay advancement)
- capture **raw observations** resulting from that interaction as Events
- preserve the exact ordering in which observations are made
- assign deterministic, monotonic sequence identifiers to admitted Events

#### The Controller MUST NOT

- parse debugger output
- interpret or classify debugger responses
- infer execution state (e.g. stopped, running, breakpoint hit)
- recognise prompts or markers semantically
- buffer, coalesce, reorder, or suppress events
- mutate DebugSession internals or derived state
- emit synthetic events to “improve” the model
- discard “boring”, noisy, or repetitive output

All interpretation, cleanup, and meaning-making belongs exclusively in
Derived State and Semantic Derivation layers.

Violations of these constraints collapse the separation between truth and meaning
and are considered architectural errors.


---

### 4. ExecutionSource: External Interaction

For a **Live Execution Source**:

- the Controller forwards the request
- the ExecutionSource translates intent into debugger commands
- the debugger executes the command

For a **Recorded Execution Source**:

- the Controller advances replay position
- no external process is involved

In both cases, the ExecutionSource’s role is the same:

> **Observe reality and emit events.**

---

### 5. Event Emission

As a result of the action, the ExecutionSource emits one or more **Events**, such as:

- execution resumed
- execution stopped
- breakpoint hit
- signal received
- error occurred

Events are:
- immutable
- ordered
- authoritative

No interpretation occurs here.

---

### 6. DebugSession: Truth Recording

The DebugSession:
- consumes emitted Events
- appends them to the session timeline
- updates replay position
- records ordering

The DebugSession may:
- request a Snapshot (based on policy)
- associate snapshots with events

The DebugSession does **not**:
- derive explanations
- update UI state
- know who issued the command

---

### 7. Snapshot Capture (Optional)

If a semantic moment is detected (e.g. stop event):

- the DebugSession requests a Snapshot
- snapshot data is captured
- snapshot is recorded as an event

Snapshots are immutable historical anchors.

---

### 8. Derived State Recalculation

Derived State is recalculated based on:
- current replay position
- available snapshots
- event history

Examples:
- current thread/frame
- visible registers
- disassembly view
- stack view

Derived State is:
- ephemeral
- reconstructible
- discardable

---

### 9. Semantic Derivation

Semantic derivation processes:
- events
- snapshots
- derived state

to produce:
- explanations
- annotations
- causal narratives

Semantic data:
- does not mutate truth
- may evolve independently
- may be incomplete or provisional

---

### 10. Rendering

UI components (tmux panes, REPL output):
- read derived state
- read semantic annotations
- render views

Rendering:
- does not affect session truth
- does not emit events
- may be refreshed freely

The user sees the result of their action.

---

## Recorded Session Flow (Key Difference)

In a recorded session:

- the REPL still emits intent
- the Controller still routes it
- the ExecutionSource advances replay
- events are replayed, not generated
- snapshots are authoritative

The flow remains identical in shape.

Only the **ExecutionSource behaviour** changes.

---

## Error Handling Flow

Errors are treated as **events**.

Examples:
- debugger communication failure
- unsupported command
- dataset corruption

Errors:
- are emitted upward
- recorded in the session
- rendered as feedback

Errors are never handled silently.

---

## What This Flow Explicitly Prevents

This interaction model forbids:

- UI talking directly to the debugger
- Controller mutating session state
- REPL parsing debugger output
- DebugSession interpreting meaning
- Semantic logic emitting events

Each concern stays in its lane.

---

## Mental Model Summary

- REPL expresses intent
- Controller routes intent
- ExecutionSource observes reality
- DebugSession records truth
- Derived State presents views
- Semantics explain meaning
- UI renders understanding

No shortcuts. No exceptions.

---

## Why This Matters

By enforcing this flow:

- live debugging stays responsive
- recorded sessions remain deterministic
- pedagogy becomes first-class
- architecture remains legible over time

This document should be used as a **reference during implementation and code review**.

If a change cannot be explained using this flow, it likely does not belong in the core.

# Semantic Runtime Model

## Purpose

The **Semantic Runtime Model** describes how *demand for meaning* flows through
Dipole during a live or replayed session, without violating the invariants of
the Event Model, Controller, or DebugSession.

It explains how downstream consumers (REPL, tmux panes, Dojo views) can express
interest in semantic information, and how Dipole arranges for the necessary
observations to occur — while preserving strict separation between:

- truth acquisition
- ordering
- semantic interpretation
- presentation

This document bridges:
- `interaction-flow.md`
- `semantic-derivation.md`

---

## Core Principle

> **Consumers subscribe to meaning, not to reality.  
> Reality is observed only to satisfy semantic demand.**

No consumer ever queries the debugger, the Controller, or the kernel directly.

---

## Position in the Architecture

The Semantic Runtime exists **downstream of the DebugSession** and **upstream of
presentation layers**.

It does **not** participate in event ingest.

Conceptually:

User Interest
↓
Subscribers
↓
Semantic Runtime
↓
Command Planning
↓
Controller
↓
ExecutionSource
↓
Events
↓
DebugSession
↓
Projections
↑
Semantic Runtime
↑
Subscribers

Truth flows upward.  
Meaning flows outward.

---

## Roles and Responsibilities

### Subscriber

A **Subscriber** is any component that consumes derived semantic information.

Examples:
- tmux panes
- REPL views
- Dojo lesson components
- analysis or export tools

A Subscriber:
- declares interest in a semantic projection
- receives updates when derived meaning changes
- never issues debugger commands
- never reads raw events directly (unless explicitly permitted)

A Subscriber has no knowledge of:
- the Controller
- the ExecutionSource
- LLDB or backend protocols

---

### Projection

A **Projection** is a pure, replayable computation over immutable inputs
(events, snapshots, derived state).

Projections:
- are deterministic
- do not emit events
- do not cause side effects
- may be recomputed at any time

This role is defined in detail in `semantic-derivation.md`.

---

### Semantic Runtime

The **Semantic Runtime** coordinates live semantic activity.

Responsibilities:
- host projection instances
- manage subscriptions
- track which projections are “active”
- recompute projections when new events arrive
- notify subscribers when derived outputs change

The Semantic Runtime:
- reads from the DebugSession
- does not mutate session state
- does not emit events
- does not interact with drivers or execution sources

It is purely downstream.

---

### Command Planner

The **Command Planner** translates *semantic demand* into *mechanical debugger interaction*.

It:
- understands which debugger commands produce which observations
- schedules raw commands via the Controller
- deduplicates and rate-limits requests
- adapts behaviour based on session mode (live vs replay)

The Command Planner:
- does not parse debugger output
- does not interpret events
- does not read projections directly (except for gating)
- issues only raw commands (e.g. `register read`)

It exists to satisfy semantic freshness, not user intent directly.

---

### Controller (Unchanged)

The Controller remains the sole ingest boundary.

It:
- forwards raw commands
- admits observations as Events
- assigns ordering
- remains unaware of subscribers, projections, or semantics

All Controller constraints defined in `interaction-flow.md` remain in force.

---

## Non-Goals and Semantic Hygiene (Non-Negotiable)

The Semantic Runtime is intentionally constrained.

It must **never**:

- mutate the event log
- introduce side effects
- depend on wall-clock time
- perform IO
- embed parsing heuristics tied to transport quirks

These constraints prevent *semantic creep*.

The Semantic Runtime exists to **coordinate meaning**, not to:
- observe reality directly
- infer truth heuristically
- compensate for missing data
- act as an interpreter or debugger proxy

Violating these constraints collapses the separation between
truth acquisition and interpretation.

---

## End-to-End Example: Register View in tmux

### 1. Subscription

A tmux pane responsible for displaying registers starts and declares:

> interest in the `RegisterSnapshot` projection

No commands are issued.

---

### 2. Semantic Runtime Activation

The Semantic Runtime observes that `RegisterSnapshot` now has an active subscriber.

---

### 3. Command Planning

The Command Planner determines that, to keep this projection meaningful,
it must observe register state when the target stops.

It schedules appropriate raw debugger commands via the Controller.

---

### 4. Reality Observation

The debugger emits output in response.

The Controller admits observations as Events.
The DebugSession records them immutably.

No semantic interpretation occurs.

---

### 5. Projection Recalculation

The Semantic Runtime recomputes the `RegisterSnapshot` projection using the
updated event log and snapshots.

---

### 6. Subscriber Update

The tmux pane receives an updated derived register view and redraws.

The pane never:
- queried the debugger
- parsed output
- interacted with the Controller

---

### 7. Replay Behaviour

During replay:
- no new commands are scheduled
- projections rebuild deterministically
- subscribers receive historical views

Semantic demand does not alter history.

---

## Live vs Replay Semantics

### Live Sessions

- projections may be partial
- planners may schedule commands
- subscribers may receive incremental updates

### Replay Sessions

- planners are disabled or inert
- no new commands are issued
- projections rebuild from recorded truth only

The same semantic runtime logic applies in both cases.

---

## Architectural Constraints (Non-Negotiable)

1. Subscribers must never issue debugger commands
2. Projections must remain pure and replayable
3. The Semantic Runtime must not emit events
4. Command Planning must not interpret observations
5. The Controller must remain unaware of semantics
6. Replay must never trigger side effects

Violating these constraints collapses separation of concerns.

---

## Relationship to Other Architecture Documents

- **Interaction Flow**  
  Defines ingest and truth flow.  
  The Semantic Runtime operates strictly downstream.

- **Semantic Derivation Model**  
  Defines how meaning is computed.  
  The Semantic Runtime defines when and why it is computed.

- **Derived State Model**  
  Supplies ephemeral views consumed by projections.

- **Snapshot Model**  
  Provides immutable anchors for semantic explanation.

---

## Summary

The Semantic Runtime Model explains how Dipole supports live, interactive,
multi-view debugging without compromising replayability or architectural clarity.

By separating:
- interest (subscribers)
- observation (controller + execution source)
- interpretation (projections)
- coordination (semantic runtime)

Dipole enables tmux, REPL, and pedagogical tooling to coexist cleanly on top of
an immutable event log.

This model ensures Dipole scales in capability without collapsing truth and meaning.

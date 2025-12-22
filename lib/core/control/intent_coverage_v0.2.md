Intent Coverage — Dipole v0.2
=============================

This document defines the **intent coverage and control guarantees** provided by
Dipole v0.2.

It completes **TS4 (Interaction & Control)** by:
- enumerating which intents are **implemented and guaranteed** in v0.2,
- defining the **architectural shape** of future intents,
- and locking the control-plane invariants required for Dojo.

This document is **normative** for the control plane.
Any change to the guarantees described here constitutes an architectural change
and must be accompanied by new tests and an explicit roadmap update.

---

Purpose
-------

Dipole v0.2 is an **architectural graduation release**.

Its purpose is to:
- re-establish Dipole on a sealed semantic and control foundation,
- unlock the **first Dojo introductory course**, and
- provide a minimal but honest baseline debugger loop:
  *breakpoint → run → step → observe → continue → exit*.

This document answers the question:

> *What may a lesson, user, or tool legitimately assume Dipole v0.2 can do?*

---

Architectural Context (Sealed)
------------------------------

By the time this document applies, the following are already sealed:

### TS1 — Event-Sourced Truth
- Event log is the sole replayable source of truth
- Events are raw transport observations only
- Append-only, ordered, replay-deterministic

### TS2 — Semantic Projections
- Meaning is derived purely from the event log
- Projections are deterministic and versioned
- Dependency surfaces are declared and enforced

### TS3 — Semantic Consumption & Distribution
- Meaning is distributed downstream-only via Frames
- Consumers and UI are read-only observers
- Replay determinism holds through rendering

### TS4 — Interaction & Control (Core)
- Intent is first-class, non-authoritative
- Validation is pure and deterministic
- Execution routes only through Controller / Driver
- Effects are observable only via Events
- Intent is not replayed

This document **does not redefine** these guarantees.
It specifies **coverage** on top of them.

---

Design Rule for v0.2 Intent Coverage
------------------------------------

All intents in v0.2 obey the same rule:

> **One intent represents one explicit, synchronous request for action.**

Each implemented intent:
- is expressed explicitly by the user,
- validates synchronously,
- executes synchronously,
- routes only through the Controller / Driver membrane,
- expresses all effects solely as Events.

v0.2 intentionally avoids:
- planners,
- execution loops,
- background control,
- async orchestration,
- UI-driven execution.

---

Implemented Intent Coverage (v0.2.0)
------------------------------------

The following intents are **implemented, tested, and guaranteed** in Dipole v0.2.  
Dojo lessons and tooling may rely on these intents existing. Architectural scaffolding (`intent.ping`) remains present to exercise TS4.

### 0. Exemplar Control Intent

#### `intent.ping`

- Exists to exercise the TS4 control path end-to-end
- Validates purely against semantic Frames
- Executes via Controller → Driver
- Produces transport observations and Events
- Carries **no semantic meaning**
- Is **not logged** and **not replayed**

This intent is architectural scaffolding and carries no user semantics.

---

### 1. Session Lifecycle Intents

#### Implemented
- `session.start`
- `session.exit`

**Guarantees**
- Session boundaries are explicit
- No implicit start/stop
- All effects are recorded as Events
- Replay reconstructs session state from Events only

---

### 2. Execution Control Intents

#### Implemented
- `run`
- `continue`
- `step`

**Guarantees**
- One intent → one execution request
- No auto-repeat
- No stepping modes
- No implicit execution loops

Each execution intent:
- routes through Controller → Driver,
- emits transport observations,
- appends Events,
- updates semantic projections deterministically.

---

### 3. Breakpoint Intents

#### Implemented
- `breakpoint.add <file>:<line>`
- `breakpoint.clear <id>`

**Guarantees**
- Breakpoint actions are explicit
- Breakpoint effects are observable only via Events
- Breakpoint state is surfaced via semantic projections
- No hidden breakpoint tables exist in the control plane

A small TS2-compatible projection (e.g. `breakpoint.list@1`)
may exist to expose breakpoint state.

---

### 4. Machine State Observation (Registers)

#### Implemented
- Register snapshot events
- Register semantic projections
- Register views in UI panes

**Guarantees**
- Observation is read-only
- No mutation or control via observation
- Register views are replay-equivalent

---

Architectural Intent Shapes (Forward-Locked)
--------------------------------------------

The following intent categories define **required shape and constraints**
for future extensions. They may evolve beyond v0.2 but must not violate
the guarantees locked here.

Examples include:
- conditional breakpoints
- watchpoints
- planned execution
- async stepping
- schedulers or planners

These are **explicitly out of scope** for v0.2.

---

What v0.2 Explicitly Does *Not* Support
---------------------------------------

- Async execution loops
- Conditional breakpoints
- Watchpoints
- “Run until” or planned execution
- Stepping modes
- Background execution
- UI-initiated execution
- Semantic shortcuts or mutation
- Implicit defaults (e.g. “latest”)
- Raw event access outside TS1

---

Replay Semantics (Restated)
---------------------------

- Intent is **not replayed**
- Intent is **not logged** in v0.2
- Replay reconstructs **effects only**
- Effects are reconstructed solely from Events
- Semantic outputs and UI rendering are replay-equivalent

Any violation of this rule is an architectural bug.

---

Dojo Contract
-------------

A Dojo introductory lesson may assume that Dipole v0.2 allows a learner to:

1. start a debugging session,
2. set a breakpoint,
3. run the program,
4. step execution,
5. observe register changes,
6. continue execution,
7. exit the session,

…and that **every change observed** can be explained by:

`Intent → Execution → Events → Semantic Projection → Frame → UI`


This contract applies **only** to the intents listed under
**Implemented Intent Coverage (v0.2.0)**.

---

Stability and Evolution
----------------------

This document defines a **stable control-plane contract**.

Future versions may add intents or planners, but must do so
*without weakening or bypassing* the guarantees locked here.

Dipole v0.2 is intentionally unflashy.
Its value lies in **legibility, honesty, and correctness**.

---

Summary
-------

Dipole v0.2 provides:

- a sealed semantic pipeline,
- a contained and explicit control plane,
- a minimal but real debugger interaction loop,
- deterministic replay,
- and a trustworthy foundation for the first Dojo course.

This document marks the **completion of TS4** and the
**dojo-readiness of Dipole v0.2**.

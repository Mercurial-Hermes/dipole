v0.2 Dojo Readiness — Dipole
===========================

This document defines the **remaining work required** to make Dipole v0.2
usable for the **Dojo introductory course**.

It is not an architectural specification.
It does not introduce new invariants.
It does not replace the test ledger.

Instead, it answers one question only:

> *What concrete capabilities must exist before a learner can successfully
> complete the first Dojo lesson using Dipole v0.2?*

This document is an **execution and readiness checklist**.
Items listed here graduate into the test ledger **only after**
their invariants are implemented and locked by tests.

---

Scope and Assumptions
---------------------

### In Scope for v0.2

- Minimal but real debugger interaction
- Explicit user-driven control only
- Breakpoints, stepping, continue, exit
- Deterministic register observation
- tmux panes as read-only semantic views
- Shell usage handled externally (e.g. Ghostty)

### Explicitly Out of Scope

- Async execution or planners
- Conditional breakpoints
- Watchpoints
- Memory inspection beyond registers
- UI-driven execution
- Implicit defaults or shortcuts
- Performance analysis
- Non-LLDB backends

These exclusions are architectural decisions, not omissions.

---

Baseline Dojo Scenario (Target Behavior)
----------------------------------------

A Dojo learner must be able to complete the following sequence
using Dipole v0.2:

1. Compile a simple program externally
2. Start a Dipole debugging session
3. Set one or more breakpoints
4. Run the program
5. Stop at a breakpoint
6. Step execution
7. Observe register changes in a pane
8. Continue execution
9. Exit the session cleanly

Every step must be explainable in terms of:

`Intent → Execution → Events → Semantic Projection → Frame → UI`


If any step feels implicit or magical, readiness is incomplete.

### Canonical Dry-Run Scenario (v0.2)

This scenario is the reference for v0.2 tests, docs, and manual dry runs.

**Target architecture:** Apple Silicon (aarch64) via LLDB. Register projections and UI ordering commit to this set only; cross-arch is out of scope for v0.2.

**Program (main.c)**
```c
#include <stdio.h>

int add(int x, int y) {
    return x + y;            // breakpoint: main.c:5 (canonical)
}

int main(void) {
    int acc = 0;
    for (int i = 0; i < 3; i++) {
        acc = add(acc, i);
    }
    printf("%d\n", acc);
    return 0;
}
```

**Build**
```
cc -g -O0 -o demo main.c
```

**Canonical breakpoint**
- `main.c:5` (inside `add`, on the return)

**Intent / CLI sequence (ergonomic verbs, one-to-one mapping)**
1) `dipole session start` → `session.start`
2) `dipole breakpoint add main.c:5` → `breakpoint.add`
3) `dipole run` → `run`
4) (stop at BP) `dipole step` → `step`
5) `dipole continue` → `continue`
6) (program exits) `dipole session exit` → `session.exit`

**Expected event/log outline (no parsing implied)**
- Command/tx events for each intent routed through Controller → Driver
- Backend/rx events reflecting:
  - breakpoint set acknowledgement
  - breakpoint hit (stop reason)
  - register dump after breakpoint hit (trigger via execution path)
  - register dump after step (trigger via execution path)
  - continue/exit output
- Monotonic `event_id`, append-only

**Replay expectation**
- Persist the event log after the run
- `dipole replay --log <path>` reconstructs semantic outputs (including `register.snapshot@1` and `breakpoint.list@1`) identically; no intent paths touched during replay

**Required projections/UI**
- `register.snapshot@1` (aarch64-only canonical ordering)
- `breakpoint.list@1` (id, file, line, enabled flag; optional hit count)
- Existing `event.kind`
- tmux panes render registers (stable order) and optional status (stop reason, file:line) read-only

---

Work Areas and Remaining Items
------------------------------

### 1. Control Plane — Intent Coverage

These items widen **intent coverage** under TS4.
They do not introduce new architectural concepts.

#### 1.1 Intent Definitions

- Define intent names and versions for:
  - `session.start`
  - `session.exit`
  - `run`
  - `continue`
  - `step`
  - `breakpoint.add`
  - `breakpoint.clear` (optional)

**Requirements**
- Intents are immutable, typed, versioned
- Intents are not logged
- Intents are not replayed
- Validation is pure and deterministic

---

#### 1.2 Intent Validation

- Add validation stubs for each intent
- Validation may be syntactic only (e.g. file:line parsing)
- Validation must not:
  - access Controller or Driver
  - mutate state
  - emit Events

---

#### 1.3 Intent Execution Routing

- Map each intent to exactly one LLDB command sequence
- Route execution exclusively through Controller → Driver
- Ensure:
  - no execution loops
  - no retries
  - no background execution

Execution failures must surface as Events.

---

#### 1.4 Control Plane Tests

For each implemented intent:
- Validation test (pure, no effects)
- Execution test (events emitted)
- Replay test (effects observable only via Events)

These tests mirror the existing TS4 exemplar tests.

---

### 2. Event Capture — LLDB Transport

These items ensure sufficient **raw observations** exist
to support semantic projections.

#### 2.1 Breakpoint Observations

- Confirm breakpoint-related LLDB output is captured as Events
- Ensure:
  - breakpoint set
  - breakpoint hit
  - stop reason

No parsing required at this stage.

---

#### 2.2 Register Observations

- Ensure register dumps are captured as Events after:
  - breakpoint hit
  - step

If missing, explicitly issue `register read` as part of execution intent.

This is execution detail, not semantic interpretation.

---

### 3. Semantic Projections (Minimal)

These items introduce **minimal TS2-compatible projections**
to support UI visibility.

#### 3.1 Register Snapshot Projection

- Add projection (e.g. `register.snapshot@1`)
- Input: raw register dump events
- Output: canonical mapping of register → value (string)

**Constraints**
- Deterministic output
- Canonical ordering
- Explicit `permitted_fields`

---

#### 3.2 Breakpoint State Projection (Optional)

- Add projection (e.g. `breakpoint.list@1`)
- Derive:
  - known breakpoints
  - location
  - optional hit count

This improves pedagogical clarity but is not strictly required
if registers suffice.

---

### 4. Semantic Feed Coverage

Ensure the semantic feed supports all new projections.

- Register new projections in the registry
- Confirm Frames can be built deterministically
- Confirm rebuild from event log yields identical Frames

---

### 5. UI / tmux Wiring (Read-Only)

No new authority. No execution control.

#### 5.1 Register Pane

- Configure a tmux pane to consume register snapshot Frames
- Render:
  - register name
  - value
- Ordering must be stable

---

#### 5.2 Optional Status Pane

- Optionally render:
  - stop reason
  - current file:line

Derived strictly from Events or projections.

---

### 6. CLI Surface (Minimal Ergonomics)

CLI is a **thin adapter** over intents.

#### Required Commands

- `dipole session start`
- `dipole breakpoint add <file>:<line>`
- `dipole run`
- `dipole step`
- `dipole continue`
- `dipole session exit`

**Constraints**
- No implicit defaults
- No “latest” shortcuts
- Errors must be explicit and instructional
- Help text should reference Dojo documentation

---

### 7. Dojo Dry Run (Gate)

Before v0.2 release, perform a **manual dry run**:

- Write the first Dojo lesson step-by-step
- Execute each command against a simple program
- Verify:
  - events are emitted
  - semantics update
  - UI panes reflect changes
  - replay reconstructs behavior

Any unexplained step indicates missing work.

---

### 8. Release Hygiene

#### 8.1 Documentation

- Cross-link:
  - roadmap
  - `interaction_and_control.md`
  - `intent_coverage_v0.2.md`
- Update README to state clearly:
  - what v0.2 is
  - what v0.2 is not

---

#### 8.2 Final Checks

- All tests green
- No TODOs in core paths
- Feature branches merged
- Tag `v0.2.0---reboot`

---

### 9. Replayability (Dojo Capstone)

- Persist event logs to disk
- Provide `dipole replay --log`
- Ensure replay is read-only
- Teach replay as reconstruction of effects

---

Graduation Rule
---------------

A work item in this document is considered **complete** when:
- the capability exists,
- its invariants are enforced by tests,
- and the relevant tests are recorded in the test ledger.

Until then, it remains a readiness item only.

---

Summary
-------

This document defines the **final execution path** to a dojo-usable Dipole v0.2.

No new architecture is required.
No invariants are weakened.
No shortcuts are introduced.

What remains is disciplined implementation, wiring, and verification.

When every item here is satisfied, Dipole v0.2 is ready to teach.

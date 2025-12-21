# Dipole Thin Slice – Test Ledger

## Passing Tests

TS0-001 DebugSession append preserves order + assigns monotonic event_id
Anchors: event-sourced truth, replay determinism
Types touched: Event, DebugSession
No dependencies: controller/driver/repl/tmux/derived/semantic
Tests:
- kernel-assigned identity (`event_id`)
- append-only, total ordering of events
- no reliance on wall-clock or physical time
Status: ✅ Passing
Notes:
- Order is logical (kernel-defined), not temporal

TS0-002 DebugSession forbids mutation of recorded truth
Anchors: event-sourced truth, replay determinism
Types touched: Event, DebugSession
No dependencies: controller/driver/repl/tmux/derived/semantic
Tests:
- event log is immutable after append
- no mutable access via public API
Status: ✅ Passing
Notes:
- immutability is enforced by type system, not runtime checks

TS0-003 — Debug Session can be deterministically replayed from event log
Anchors: event-sourced truth, replay determinism
Types touched: Event, DebugSession
No dependencies: controller/driver/repl/tmux/derived/semantic
Tests:
- a `DebugSession` reconstructed solely from an existing event log is equivalent to the original session
- replay requires no hidden or external state
Status: ✅ Passing

TS1-001 — Projections are replay-equivalent (category counts)
Anchors: projection purity, replay determinism
Types touched: Event, DebugSession, Projection
No dependencies: controller/driver/repl/tmux/semantic
Tests:
- a projection computed over an original event log
- produces identical results when computed over a replayed session
- projection output depends *only* on the event sequence
Status: ✅ Passing
Notes:
- establishes projections as pure functions over immutable truth
- no hidden state or session identity leakage

TS1-002 — Projections preserve event ordering semantics (category timeline)
Anchors: projection purity, ordering invariants
Types touched: Event, DebugSession, Projection
No dependencies: controller/driver/repl/tmux/semantic
Tests:
- a projection that preserves event order (timeline)
- yields identical ordered output on replay
- confirms projections do not introduce reordering or interpretation
Status: ✅ Passing
Notes:
- projections may transform shape, but must preserve logical order
- meaning is not inferred, only reflected

TS1-003 — Controller admits raw transport observations as ordered Events
Anchors: Controller ingest boundary, event-sourced truth
Types touched: Event, DebugSession, Controller, Driver (fake)
No dependencies: repl/tmux/derived/semantic
Flow the tests prove:
- when asked to issue a command, the Controller forwards it to the driver
- the driver produces raw transport observations (tx / rx / prompt)
- the Controller appends **exactly those observations** to the event log
- Events are appended in order with deterministic, monotonic `event_id`
- identical inputs produce identical event logs on replay
Tests:
- Controller → Driver interaction produces tx, rx, prompt observations
- no observations are dropped, reordered, or synthesised
- event sequence is replay-equivalent
Status: ✅ Passing
Notes:
- events represent transport-level observations only
- no parsing, interpretation, or semantic meaning is introduced

## TS1-004 — Real Transport Noise Enters the Event Log

**Status:** ✅ Passed
**Branch:** `exp/v0.2.0/thin-slice-1`
**Predecessor:** TS1-003
**Successor:** TS2-001 (First Semantic Projection)

---

### Purpose

Introduce **real transport pressure** into the system by admitting observations from a **live, transport-backed debugger backend**, while preserving all invariants established in TS1-003.

This slice validates **architectural resilience under reality**, not correctness of interpretation.

---

### Architectural Anchors

* Event-sourced truth
* Controller as sole ingest boundary
* Kernel-owned ordering
* Replay determinism
* Observation without interpretation

---

### Locked Invariants

The following invariants were established in TS1-003 and are **explicitly preserved**:

* No event without an observation
* No semantic meaning at ingress
* No kernel dependency on drivers
* No controller-side interpretation
* No replay-breaking state
* Event ordering is kernel truth

TS1-004 intentionally increases noise, fragmentation, and timing nondeterminism —
but **introduces no new meaning**.

---

### Scope of Change (As Built)

#### New Transport Components

* **`pty.zig`**

  * PTY pair creation and lifecycle management
  * Non-blocking, CLOEXEC-safe transport primitive

* **`pty_raw_driver.zig`**

  * Transport-backed implementation of the `Driver` boundary
  * Emits raw byte observations exactly as read
  * No buffering across polls
  * No aggregation, parsing, or detection

* **`lldb_launcher.zig`**

  * Responsible solely for spawning and managing LLDB
  * Produces a live PTY master FD
  * No Driver logic, no interpretation

#### Controller Behavior

* Continues to mechanically:

  * forward raw commands
  * poll for observations
  * admit observations as Events
* Performs **no parsing, aggregation, or classification beyond ingress category**

#### Kernel Behavior

* Unchanged
* Assigns monotonic `event_id`
* Preserves observation order as seen

---

### Explicit Non-Goals (Confirmed)

TS1-004 does **not** introduce:

* LLDB output parsing
* Prompt detection
* Execution or stop semantics
* Breakpoint or frame meaning
* Snapshots or derived state
* Projection changes
* Async model redesign

This slice is about **noise, not meaning**.

---

### Tests Added / Extended

#### Unit-Level

* `pty_raw_driver_test.zig`

  * Verifies:

    * non-blocking behavior
    * no aggregation across polls
    * verbatim byte emission
    * correct send semantics

* `lldb_launcher_test.zig`

  * Verifies:

    * LLDB spawn (attach + launch)
    * PTY wiring correctness
    * interrupt and shutdown behavior
    * child process lifecycle

#### Integration-Level (Critical)

* **Controller + Real LLDB + PTY-backed Driver**

  * Issues real commands into a real debugger
  * Admits noisy, nondeterministic transport output
  * Asserts:

    * events are produced
    * categories remain valid
    * `event_id` is strictly monotonic
    * no semantic leakage occurs

Tests intentionally avoid:

* asserting exact event counts
* asserting content ordering
* asserting prompt placement

---

### Acceptance Criteria (Met)

TS1-004 is complete because:

* A real, transport-backed debugger feeds data into the system
* The event log contains raw, noisy, transport-level observations
* All invariants from TS1-003 remain intact
* Event ordering remains kernel-owned and monotonic
* Projections replay cleanly from noisy logs

> If TS1-003 proved architectural correctness,
> TS1-004 proves architectural resilience.

---

### Notes

* This slice deliberately increases entropy.
* Failures are allowed only at explicit boundaries.
* The kernel remains boring by design.
* The shape of Events may evolve — their meaning must not.

---

### Ledger Outcome

* ✅ Real debugger transport admitted
* ✅ Architecture survives contact with reality
* ❌ No semantics introduced
* ❌ No kernel contamination
* ❌ No replay regressions

Reality has entered the system —
and the system holds.

# TS2-001 — First Semantic Projection (Event Kind Classification)

**Anchors:** semantic derivation, projection purity, replay determinism  
**Types touched:** `Event`, `DebugSession`, `Projection`  
**Dependencies:** none (controller / driver / repl / tmux / kernel explicitly excluded)  
**Status:** ✅ **Passed**

---

## Tests

- A projection derives **exactly one semantic `EventKind` per `Event`** in the log  
- Derived output length matches input event count  
- Derived output **preserves event ordering as given by the event log slice**  
- Projection depends **only** on:
  - `Event.category`
  - `Event.event_id` (identity only; not ordering)
- Replayed event logs produce **identical derived semantic results**

---

## Notes

- This is the **first introduction of meaning** above the event log  
- The projection is:
  - pure  
  - deterministic  
  - lossy  
  - allocator-injected  
  - downstream-only  
- The projection is strictly **read-only over immutable truth**  
- No debugger semantics, intent, authority, or state are inferred  
- `Event.timestamp` is explicitly ignored and proven semantically irrelevant  
- Establishes that **semantic meaning can be layered without contaminating TS1**  
- Ordering authority remains exclusively with the event log; semantics must not reinterpret history  

---

## Summary

TS2-001 proves that interpretive semantic meaning can exist as a **pure, replayable, downstream layer**
over the event log without introducing authority, causality, or state.

# TS2-002 — Projection Identity & Registry

**Anchors:** semantic identity, meaning stability, non-operational structure  
**Types touched:** `ProjectionId`, `SemanticVersion`, `ProjectionDef`, `ProjectionRegistry`, `EventField`  
**Dependencies:** none (execution, planner, subscribers, runtime explicitly excluded)  
**Status:** ✅ **Passed**

---

## Tests

- Semantic meaning is **discoverable by name** via `ProjectionId`
- Projection identity is **pure declarative data**:
  - no function fields
  - no allocators
  - no pointers to mutable state
- The registry is **unambiguous**:
  - no duplicate `(name, version)` pairs
- **Unversioned and versioned projections may coexist**:
  - lookup is exact
  - no silent replacement or implicit upgrade
- Every projection **explicitly declares its semantic dependency surface**:
  - `permitted_fields` is non-empty
  - only TS2-001–allowed fields are permitted

*(Non-operational registry invariant is documented and enforced by structure and review, not an automated test.)*

---

## Notes

- TS2-002 introduces **identity for meaning**, not new meaning
- The registry is:
  - static
  - declarative
  - non-operational
  - non-authoritative
- Projection identity:
  - names semantic meaning
  - is stable across rebuilds and replays
  - is independent of execution, ordering, or consumption
- Semantic versioning is:
  - explicit
  - additive
  - opt-in
  - non-replacing
- `EventField` establishes a **visible semantic firewall**:
  - dependency surfaces are declared in data
  - enforcement is structural and test-driven
- No projection execution, scheduling, caching, or runtime behavior is introduced
- No coupling to planners, UI, or debugger subsystems exists

---

## Summary

TS2-002 establishes a **stable, explicit, and inert identity layer for semantic meaning** in Dipole.
Semantic interpretations are now:

- named
- discoverable
- unambiguous
- explicitly versioned
- explicit about their dependency surfaces

All without introducing execution, authority, or runtime behavior.

This completes the semantic identity foundation and cleanly prepares the system
for TS2-003 (projection contracts vs implementation drift).

## Next Test (RED)

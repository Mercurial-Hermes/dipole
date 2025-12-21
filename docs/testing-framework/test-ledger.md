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

# TS2-003-001 — Projection Contract Drift (Irrelevant Field Stability)

**Anchors:** semantic firewall, contract stability, non-dependence on raw events  
**Types touched:** `ProjectionDef`, `ProjectionRegistry`, `Event`, `EventField`  
**Dependencies:** TS1 (event log), TS2-001 (projection purity), TS2-002 (registry & identity)  
**Status:** ✅ **Passed**

---

## Tests

- Projection output is **stable under irrelevant event drift**:
  - two event logs differing only in fields *outside* `permitted_fields`
  - produce **deep-equal semantic output**
- Projection execution is **deterministic**:
  - repeated runs over the same log yield deep-equal results
- The semantic dependency surface is **registry-enforced**:
  - `permitted_fields` are read exclusively from registry metadata
  - mutated fields are verified to be outside the declared dependency set
- No observable side effects occur during projection execution
- Projection output depends **only** on declared semantic inputs

---

## Notes

- This test establishes the **semantic firewall** between:
  - raw event payloads
  - projection implementations
  - downstream consumers
- Drift detection is:
  - structural
  - functional
  - test-driven
- No runtime instrumentation, reflection, allocation counting, or introspection is used
- The test proves **non-accidental semantics**:
  - projections do not implicitly couple to raw event structure
- Enforcement is semantic, not behavioural:
  - equality and determinism only
  - no inspection of internal execution

---

## Summary

TS2-003-001 proves that **semantic meaning in Dipole is contract-bound, not incidental**.

Projection implementations are now demonstrably:

- insulated from irrelevant event changes
- stable under replay
- safe to expose downstream
- trustworthy as semantic abstractions

This test is the **mandatory gatekeeper** for TS3 exposure and completes the
semantic safety bridge between the semantic foundation (TS2) and consumer-facing
contracts (TS3).

# TS2-003-002 — Projection Contract Drift (Permitted Field Sanity Check)

**Anchors:** semantic firewall validation, harness integrity, in-scope dependency verification  
**Types touched:** `ProjectionDef`, `ProjectionRegistry`, `Event`, `EventField`  
**Dependencies:** TS1 (event log), TS2-001 (projection purity), TS2-002 (registry & identity)  
**Status:** ✅ **Passed**

---

## Tests

- The drift test harness correctly classifies **in-scope field changes**:
  - mutated fields are verified (via registry metadata) to be inside `permitted_fields`
- For a projection where permitted-field changes are expected to affect meaning:
  - semantic output differs under in-scope mutation
- Projection execution remains **deterministic per log**:
  - repeated runs over the same event log yield deep-equal results
- Premises are explicitly enforced:
  - event ordering, identity, and non-permitted fields remain unchanged
  - only declared semantic inputs are varied

---

## Notes

- This test is a **negative control** for TS2-003:
  - it prevents a false sense of safety where the drift harness always reports equality
- The test is intentionally **projection-specific**:
  - it selects a projection (`event.kind`) where semantic change is expected
- No assertion is made that *all* permitted-field changes must alter output
- No runtime instrumentation, reflection, or allocation counting is used
- All dependency classification is sourced exclusively from registry metadata

---

## Summary

TS2-003-002 proves that the **projection contract drift harness is capable of observing
meaningful, in-scope semantic changes**.

Together with TS2-003-001, this establishes that:

- irrelevant field changes are safely ignored
- permitted field changes are not artificially suppressed
- semantic stability in Dipole is enforced by contract, not accident

This completes the negative-control side of the TS2-003 semantic firewall.

# TS2-003-003 — Drift Harness Determinism (Registry Projections Repeatable)

**Anchors:** harness determinism, replay stability, semantic measurement integrity  
**Types touched:** `ProjectionRegistry`, `ProjectionDef`, `Event`  
**Dependencies:** TS1 (event log), TS2-001 (projection purity), TS2-002 (registry & identity), TS2-003-001/002  
**Status:** ✅ **Passed**

---

## Tests

- The drift-test harness iterates **registered projections** and enforces repeatability:
  - each covered projection is executed multiple times over the same event log
- Projection execution is **deterministic per log**:
  - repeated runs yield deep-equal semantic output
- Input immutability is enforced:
  - the event log passed to the projection is not mutated
- Harness coverage is explicit and enforced:
  - missing harness support for a registered projection causes the test to fail
- Execution conditions are controlled:
  - same allocator instance
  - identical inputs
  - no reliance on external state

---

## Notes

- This test validates the **measurement harness**, not projection semantics.
- It guards against:
  - hidden mutable state
  - non-repeatable execution
  - accidental dependence on allocator or iteration instability
- Ordering stability is enforced implicitly:
  - projections returning ordered structures must be repeatable
  - projections with unstable representations are not TS3-safe until canonicalized
- The test intentionally fails loudly when:
  - a new projection is added without deterministic harness coverage

---

## Summary

TS2-003-003 proves that the **TS2-003 drift-testing harness is itself deterministic,
repeatable, and trustworthy**.

Together with TS2-003-001 and TS2-003-002, this completes the semantic firewall bridge:
- irrelevant-field drift is ignored
- permitted-field drift is observable
- the measuring instrument is stable

With TS2-003 complete, Dipole semantics are now safe for TS3 consumer exposure.

---

### TS3-001-001 — CLI lists registered projections (identity only)

**Intent**  
Expose the semantic registry as a stable, read-only consumer contract.  
This test establishes that semantic meaning is discoverable **only by explicit identity**
and that the CLI does not execute projections or access the event log.

**Anchors**
- Semantic consumption boundary
- Registry-driven meaning
- Consumer read-only contract

**Given**
- A semantic registry with one or more registered projections
- Each projection defined by `(ProjectionId, Version)`

**Expect**
- `dipole semantic list` succeeds
- Output is canonical JSON
- Each entry contains **identity only**:
  - projection name
  - explicit version (if present)
- Ordering is stable and deterministic
- No projection execution occurs
- No event log access occurs
- Stdout contains the JSON payload
- Stderr is empty
- Exit code is `0`

**Not Proved**
- Projection correctness
- Semantic execution
- Version selection or defaulting
- Event log access

**Notes**
- This CLI is a *witness*, not a source of truth
- Tests are authoritative; the binary confirms end-to-end wiring
- This slice intentionally exposes metadata only

---

### TS3-001-002 — CLI show requires explicit version (no “latest”)

**Intent**  
Enforce that semantic consumers cannot access meaning without explicitly
naming a semantic version. This slice proves that **no implicit version
selection** occurs at the consumer boundary.

**Anchors**
- Explicit semantic identity
- Consumer non-inference
- Versioned meaning contract

**Given**
- A semantic registry containing a projection name with one or more versions

**Expect**
- `dipole semantic show <ProjectionId>` fails
- Failure indicates that an explicit version is required
- Error token is `ERR_MISSING_VERSION`
- Exit code is non-zero
- Stdout is empty
- Stderr contains a single, stable error token

**Also Expect**
- `dipole semantic show <ProjectionId>@<Version>` passes selector validation
- No fallback to “latest” or default version occurs
- Selector validation is deterministic

**Not Proved**
- Projection execution
- Event log access
- Semantic correctness
- Output formatting for successful `show`

**Notes**
- `show` is a metadata-level consumer only
- This slice deliberately rejects convenience to preserve correctness
- Any defaulting or ergonomic behavior must live above TS3

---

### TS3-001-003 — CLI eval is replay-deterministic and replay-equivalent

**Intent**  
Establish that semantic execution performed by a CLI consumer is:
- replay-deterministic, and
- equivalent to direct invocation of the projection implementation.

This slice proves that semantic meaning, when explicitly requested, is
**pure, stable, and reproducible**.

**Anchors**
- Replay determinism
- Projection purity
- Explicit semantic execution
- Canonical output contract

**Given**
- A fixed event log `L`
- A projection identified explicitly as `(ProjectionId, Version)`

**Expect**
- `dipole semantic eval <ProjectionId>@<Version> --log <path>` succeeds
- Running the command multiple times with the same inputs yields
  byte-for-byte identical output
- Output is identical to direct invocation of the projection
  implementation over `L`, after canonical encoding
- Stdout contains only the semantic result
- Stderr is empty
- Exit code is `0`

**Also Expect**
- Selector validation follows TS3-001-002 rules (explicit version required)
- Invalid selectors or logs produce stable error tokens and exit codes
- No fallback or inference occurs at any stage

**Not Proved**
- Performance characteristics
- Incremental or streaming execution
- Subscription or live feeds
- Projection correctness beyond equivalence to direct invocation

**Notes**
- Semantic execution is explicit and opt-in
- Canonical encoding is part of the consumer contract
- This slice introduces execution while preserving TS3’s
  non-authoritative, read-only semantics

---

### TS3-001-004 — Unknown ProjectionId fails safely

**Intent**  
Ensure that semantic consumers fail cleanly and deterministically when
referencing a projection identity that does not exist in the registry.
This slice prevents implicit substitution, guessing, or fallback behavior
at the consumer boundary.

**Anchors**
- Explicit semantic identity
- Consumer safety
- Registry authority

**Given**
- A semantic registry that does not contain the referenced `ProjectionId`

**Expect**
- `dipole semantic show <UnknownProjectionId>@<Version>` fails
- Error token is `ERR_UNKNOWN_PROJECTION_ID`
- Exit code is non-zero
- Stdout is empty
- Stderr contains a single, stable error token

**Also Expect**
- No projection execution occurs
- No registry fallback or substitution occurs
- No implicit version selection or inference occurs
- Failure is deterministic and replayable

**Not Proved**
- Projection execution
- Event log access
- Semantic correctness for known projections

**Notes**
- The registry is the sole authority for valid semantic identities
- This slice enforces a fail-fast consumer contract
- Any aliasing, migration, or compatibility logic must live above TS3

---

## TS3-010-001 — Feed frame identity is keyed by ProjectionId

**Status:** ✅ Passing

**Anchors:**
- Downstream-only semantic distribution
- Explicit semantic identity
- No raw event leakage

**Types touched:**
- `Frame`
- `ProjectionId`
- `SemanticVersion`
- `Feed`

**Dependencies:**
- TS1 — Event Log (truth)
- TS2 — Semantic Projections
- TS3-001 — Semantic identity (explicit versioning)

**Given:**
- A semantic feed configured to publish frames for a fixed set of projection identities  
  `{ P1@v, P2@v, ... }`
- A fixed event log slice

**Expect:**
- Every published frame includes its originating `ProjectionId`
- Each frame carries an explicit version (or explicit unversioned identity)
- Frames cannot exist without a `ProjectionId`
- No API exists to emit or subscribe to raw events

**Notes:**
- Establishes identity as a first-class invariant of semantic distribution
- Prevents anonymous or defaulted semantic outputs
- Reinforces that feed output is semantic, not transport-level

---

## TS3-010-002 — Feed is replay-equivalent to direct projection

**Status:** ✅ Passing

**Anchors:**
- Replay determinism
- Semantic non-authority
- Projection purity

**Types touched:**
- `Feed`
- `Frame`
- `ProjectionId`
- `Event`

**Dependencies:**
- TS1 — Event Log (truth)
- TS2 — Semantic Projections
- TS3-010-001 — Feed identity invariants

**Given:**
- A fixed, immutable event log `L`
- A semantic feed configured for a specific projection identity `P@v`

**Expect:**
- The frame produced by the feed for `P@v` is byte-identical to the result of directly executing `P@v(L)`
- Rebuilding the feed from scratch over `L` produces the same final frame
- No additional state, ordering, or side effects influence the output

**Notes:**
- Confirms the feed is a pure distribution mechanism, not a semantic transformer
- Guarantees feed outputs are derivable, reproducible, and non-authoritative
- Establishes that semantic pub/sub does not weaken replay guarantees

---

## TS3-010-003 — Feed publishes only derived meaning (no raw event subscription)

Intent
Prove that TS3 distribution primitives expose derived semantic frames only, and that raw event access or subscription is unrepresentable by API design.

This test establishes the semantic firewall between:

* TS1 / TS2 (event truth, projections)
* TS3 consumers (CLI, UI, REPL, tmux, etc.)

---

Given

* The feed API as exported from `lib/core/semantic/feed.zig`
* A consumer wishing to access raw events or subscribe to the event log via TS3 mechanisms

---

Expect

* No feed API exists that:

  * returns Event, EventView, or EventSlice
  * allows subscription, polling, iteration, or callbacks over raw events
* The only outputs produced by the feed are Frame values
* Frame.payload contains derived semantic meaning only (opaque, canonical bytes)
* Raw events are accessible only via direct invocation paths (TS1/TS2), not via TS3 distribution primitives

---

Proven by

* API surface restriction

  * Feed exports only:

    * buildFrame(alloc, ProjectionId, []const Event) !Frame
    * buildFrames(alloc, []const ProjectionId, []const Event) ![]Frame
  * No subscription, iterator, polling, or event-returning API exists

* Type erasure at the TS3 boundary

  * Frame.payload is []u8 (canonical JSON bytes)
  * Frame contains no event references, log indices, or event metadata

* Dependency direction

  * Feed depends only on projections and the registry
  * Feed has no access to controller, debug session, or event storage

* Unsupported-by-construction

  * Raw event subscription is not an error case — it is not representable

---

Notes

* This test is intentionally non-runtime

* The architectural guarantee is stronger than an error condition:
  “A TS3 consumer cannot accidentally or deliberately access raw events through the feed.”
* Any future addition of raw-event access to TS3 distribution primitives constitutes a TS3 contract violation and requires a new thin slice

Status  
✅ Passing (by construction / API-level guarantee)

---

### TS3-010-004 — Feed version opt-in is enforced

**Intent**  
Prove that TS3 feed consumers must explicitly opt in to a projection version, and that no implicit “latest” or ambiguous version resolution is permitted. This test enforces the rule that version is part of projection identity, and that ambiguity is a hard failure.

**Given**
- Two versions of the same projection exist: `P@v1`, `P@v2`
- A consumer attempts to request projection `P` without specifying a version

**Expect**
- Feed operation fails clearly and deterministically
- Failure indicates missing or ambiguous version
- No implicit “latest” version is selected
- No Frame is produced
- No ambiguous or partially derived output is returned

**Proven by**
- Registry-level ambiguity detection:
  - `ProjectionRegistry.nameHasMultiple(name)` correctly identifies multiple versions
  - Unversioned `ProjectionId` is rejected when ambiguity exists
- Feed validation logic:
  - `ensureRegistered` returns `error.UnknownVersion` for unversioned, ambiguous projections
- Explicit test:
  - Calling `buildFrame` with an unversioned `ProjectionId` when multiple versions exist fails with `UnknownVersion`

**Notes**
- This is a consumer-facing semantic invariant
- Unlike TS3-010-003, this behavior is enforced via runtime validation
- This test prevents accidental coupling to registry ordering or future “latest” shortcuts

**Status**  
✅ Passing

## TS3-UI-001 — REPL & tmux Reintroduction (Read-Only Consumers)

**Intent:**
Prove that UI surfaces are strict, downstream-only consumers of semantic frames, with no authority over events, projections, or feed internals.

This slice establishes the **UI adapter boundary** as a semantic diode: meaning flows in, rendering flows out, and nothing flows back upstream.

---

### TS3-UI-001-001 — UI subscribes to feed and renders frames

**Given**

* A semantic feed capable of producing `Frame` values for a specific `ProjectionId@version`
* A UI adapter configured for exactly that same `ProjectionId@version`

**Expect**

* Adapter consumes `Frame` values only
* Adapter produces a render output (structured render model)
* Adapter performs no projection execution or semantic derivation
* Adapter has no access to:

  * raw events
  * event logs
  * projection functions
  * feed internals
* Adapter enforces strict `ProjectionId@version` matching

  * mismatches fail with `ProjectionIdMismatch`
  * no implicit versioning or fallback is permitted

**What this test proves**

* UI code is downstream-only and read-only
* Semantic meaning is fully decided upstream of the UI
* Version is part of semantic identity everywhere
* UI surfaces cannot influence or reconstruct meaning

**Explicitly out of scope**

* tmux behavior
* terminal I/O
* REPL interaction
* subscription or routing mechanics
* async or transport concerns

**Status:** ✅ Passing

---

### TS3-UI-001-002 — UI cannot issue commands / mutate truth

**Given**
- A UI adapter instance

**Expect**
- No API exists to append events
- No API exists to issue raw commands
- Any attempt to route “input” is not expressible in TS3 types

**What this test proves**
- UI authority is structurally impossible, not merely rejected at runtime
- UI adapters are downstream-only by API construction
- Mutation of event truth is confined strictly upstream of TS3

**Notes**
- This invariant is enforced by the absence of APIs and imports, not by runtime checks
- No executable test is required or meaningful here

**Status:** ✅ Passing (by construction)

---

### TS3-UI-001-003 — UI is replay-equivalent (rendered output stable under replay)

**Given**

* A fixed event log `L`
* A `ProjectionId@version` `P@v`
* A UI adapter configured for `P@v`

**When**

* Run A:

  * Build feed over `L`
  * Produce `Frame(P@v)`
  * Render via UI adapter
* Run B:

  * Rebuild feed from scratch over the same `L`
  * Produce `Frame(P@v)`
  * Render via a fresh UI adapter instance

**Expect**

* Rendered outputs are deeply identical

  * same title
  * same section structure and ordering
  * same row structure and ordering
  * identical label/value strings
* No nondeterminism introduced at the UI boundary

**What this test proves**

* UI adapters are pure functions of `(Frame + configuration)`
* UI state is rebuildable from semantic truth
* “Live” UI rendering is replay-equivalent
* UI does not introduce hidden state, timestamps, or unstable ordering

**Notes**

* UI adapters continue to consume `Frame` values only
* Replay orchestration occurs outside the adapter
* No access to events, projections, or feed internals is granted

**Status:** ✅ Passing

---

## Next Test (RED)

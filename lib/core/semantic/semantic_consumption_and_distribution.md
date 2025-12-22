# Semantic Consumption and Distribution (TS3)

## Purpose

This document defines how **semantic meaning is consumed and distributed** in Dipole,
following the completion of the semantic foundation (TS2).

TS3 introduces **observation of meaning** — without introducing authority, execution,
or mutation.

It is the first point where semantics leave the kernel.

---

## Architectural Position

TS3 sits **strictly downstream** of the semantic layer.

It does **not** define meaning.
It does **not** execute meaning.
It does **not** decide meaning.

It allows meaning to be:

- observed
- shared
- reasoned about
- rendered

without compromising semantic purity.

---

## Preconditions (Established by TS2)

Before TS3 begins, the system guarantees:

### Event Log
- Append-only
- Ordered
- Replay-deterministic
- Sole source of truth

### Projections
- Pure functions of the event log
- Replay-deterministic
- Non-authoritative
- No side effects

### Projection Identity & Registry
- Stable semantic names (`ProjectionId`)
- Explicit version coexistence
- Declarative, inert registry
- Explicit dependency surfaces (`permitted_fields`)
- No execution or scheduling semantics

All meaning is **named, inert, and explicit**.

---

## TS3 Design Goal

Enable **safe consumption and distribution of semantic meaning**.

This is the transition from:

> “Meaning exists”

to:

> “Meaning can be observed and shared safely.”

---

## Non-Goals (Explicit Exclusions)

TS3 must **not**:

- Introduce execution or control flow
- Mutate the event log
- Reintroduce semantic authority
- Collapse semantics into UI concerns
- Allow implicit version selection (e.g. “latest”)
- Allow consumers to subscribe to raw events

---

## Core Invariants

Across all TS3 mechanisms:

- Event log append remains the **only ingest path**
- Projections remain **pure and replayable**
- Consumers reference meaning **by `ProjectionId` only**
- Projection version selection is **explicit**
- All dataflow is **downstream-only**

---

## Semantic Consumers

A **consumer** is any component that:

- selects a projection by `ProjectionId`
- observes derived semantic output
- does not mutate state
- does not execute commands

Consumers are **non-authoritative observers**.

Examples include:
- CLI tools
- REPLs
- tmux panes
- visualisation layers
- diagnostic tooling

---

## Projection Feed (Distribution Layer)

TS3 introduces a **projection feed**:

- A downstream-only semantic distribution mechanism
- Publishes derived semantic frames keyed by `ProjectionId`
- Fully replayable from the event log
- Deterministic under replay
- Rebuildable at any time

### Constraints

- No raw event subscriptions
- No side effects
- No execution hooks
- No mutation

The feed carries **meaning only**, never authority.

---

## UI as a Consumer

UI components (REPL, tmux, etc.) are treated as **ordinary consumers**.

They:
- subscribe to the projection feed
- render semantic output
- do not issue commands
- do not control execution

UI is **strictly downstream** of semantics.

---

## Resulting System Properties

After TS3:

- Semantic meaning is:
  - consumable
  - distributable
  - observable in real time
- Multiple consumers can coexist safely
- Replay determinism is preserved end-to-end
- No execution authority has entered the system

---

## Relationship to Future Work

TS3 completes the **semantic half** of Dipole.

It sets the stage for TS4, where:
- execution is reintroduced explicitly
- authority boundaries are made concrete
- planners and controllers are attached deliberately

TS3 ensures that when execution returns, it does so on a **stable, observable semantic foundation**.

---

## Tests (TS3)

This section defines the **test ledger** for TS3.
Tests are written to prove TS3 invariants without introducing execution, authority, or UI coupling.

### TS3 Global Test Invariants

Every TS3 test must preserve these invariants:

- Event log append remains the only ingest path
- Projections remain pure and replay-deterministic
- Consumers reference meaning by `ProjectionId` only
- Version selection is explicit (no fallback to “latest”)
- Dataflow is downstream-only
- Consumers cannot subscribe to raw events

Where possible, tests should be phrased as:
- “Given the same log, derived meaning is identical”
- “Consumers cannot observe meaning they did not explicitly name”
- “Feed and consumers are replay-equivalent to direct projection”

---

## TS2-003 — Projection Contract Drift (Bridge Slice)

**Intent:** Prove that projection implementations do not depend on fields outside `permitted_fields`,
using synthetic event-pair tests (semantic non-dependence). No runtime instrumentation.

### TS2-003-001 — Drift: irrelevant field changes do not change projection output

**Intent**  
Prove that a projection’s semantic output does not depend on event fields outside its declared
`permitted_fields`. This test establishes the semantic firewall required for safe TS3 exposure.

---

**Given**
- A projection `P` registered in the projection registry with an explicit  
  `permitted_fields = { … }`
- Two event logs `L1` and `L2` such that:
  - `L1` and `L2` have identical length and ordering
  - Corresponding events have identical `seq` (or identity), category/kind, and structure
  - `L2` differs from `L1` **only** by a change to one or more fields that are **not** listed in
    `P.permitted_fields`
  - The mutated field(s) are verified (via registry metadata) to be outside
    `permitted_fields`

---

**When**
- The projection `P` is executed over `L1`
- The projection `P` is executed over `L2`

---

**Expect**
- `P(L1) == P(L2)` (deep semantic equality)
- Repeated execution is deterministic:
  - `P(L1)` run twice yields deep-equal results
  - `P(L2)` run twice yields deep-equal results
- No observable side effects occur during projection execution
- Projection output is derived solely from declared `permitted_fields`

---

**Notes**
- This test asserts semantic non-dependence, not behavioural inspection.
- No runtime instrumentation, allocation counting, reflection, or introspection is permitted.
- `permitted_fields` must be sourced exclusively from registry metadata.
- This test is the semantic firewall that makes TS3 consumer exposure safe.

---

### TS2-003-002 — Drift: permitted field changes may change output (sanity check)

**Intent**  
Prove that the TS2-003 drift harness is capable of detecting *in-scope* changes, and is not
accidentally freezing or masking all variation. This is a negative-control test for the
semantic firewall.

---

**Given**
- A projection `P` registered with explicit `permitted_fields`
- Two event logs `L1` and `L2` such that:
  - `L1` and `L2` have identical length, ordering, and event identity
  - `L2` differs from `L1` **only** by a change to one or more fields
    that are **inside** `P.permitted_fields`
  - The mutated field(s) are verified (via registry metadata) to be within
    the declared dependency surface

---

**When**
- The projection `P` is executed over `L1`
- The projection `P` is executed over `L2`

---

**Expect**
- No assertion of semantic equality is made between `P(L1)` and `P(L2)`
- The test harness explicitly classifies the mutation as **in-scope**
  according to registry metadata
- Projection execution remains deterministic for each log independently

---

**Notes**
- This test does **not** assert that output *must* change.
- Its sole purpose is to prove that the drift harness:
  - distinguishes permitted vs non-permitted fields
  - does not trivially pass by suppressing all differences
- This test is a **negative control** and must not encode projection-specific semantics.

---

### TS2-003-003 — Harness determinism (registry-wide repeatability)

**Intent**  
Prove that the TS2-003 drift-test harness is deterministic and replay-stable by running
**all registered projections** under identical conditions and asserting repeatable outputs.
This ensures drift detection is reliable and reproducible.

---

**Given**
- A projection registry `R` containing one or more projection definitions
- A fixed event log `L`
- A deterministic execution environment:
  - the same allocator instance is used for repeated runs
  - hash iteration / hashing behaviour is stable (no randomized hash seeding)
  - no reliance on wall-clock time, OS state, RNG, or other external nondeterminism
  - no global mutable state is consulted or mutated

---

**When**
- The harness iterates **every projection** `P` in `R` (or every projection in a defined subset
  explicitly named by the harness)
- For each `P`, the harness executes `P(L)` at least twice under identical conditions
- The harness compares outputs using the canonical comparison primitive used elsewhere
  in TS2/TS3 (e.g., canonical JSON bytes, or a defined type-based deep equality for the
  projection’s output type)

---

**Expect**
For each projection `P` exercised by the harness:

- Repeatability:
  - `P(L)` run #1 is equal to `P(L)` run #2 under the harness’s canonical comparison primitive
- Ordering stability:
  - where ordering is part of `P`’s contract, the ordering is stable across runs
  - if `P` returns maps/sets, determinism requires **canonicalization** (e.g., sorting keys)
    before returning or before serialization; projections that rely on hash iteration order
    without canonicalization must be detected as non-deterministic and fail
- Side-effect safety (concrete, checkable):
  - the input log `L` is not mutated (byte-for-byte equality of the input slice / events)
  - no global state mutation is performed (no global counters, caches, registries, or
    singleton state changes)

---

**Notes**
- This test validates the **harness repeatability contract**, not semantic correctness.
- It does **not** assert:
  - cross-log equality
  - drift classification
  - relevance/irrelevance of field changes
- Passing TS2-003-003 is a prerequisite for trusting:
  - TS2-003-001 (irrelevant-field drift firewall)
  - TS2-003-002 (permitted-field negative control)

---

## TS3-001 — First Consumer (CLI)

**Intent:** Prove that a minimal consumer can list and show semantic meaning safely,
with explicit `ProjectionId + version` selection.

### TS3-001-001 — CLI lists registered projections (identity only)

**Given**
- A projection registry with `N` projections
  - including multiple versions for the same `ProjectionId.name`

**When**
- `dipole semantic list` (or `cli list`) is executed

**Expect**
- Output is canonical JSON
- Output contains **only identity + inert metadata** for each projection:
  - `projection_id`
  - `version` (explicit; never implied “latest”)
  - (optional) `permitted_fields`
- Output ordering is stable (sorted by `(name, version)` under a frozen rule)
- No projection execution occurs during listing:
  - listing is registry-data-only by construction (no function pointers available)

### TS3-001-002 — CLI show requires explicit version (no “latest”)
**Given**
- A projection name with multiple versions registered

**Expect**
- `cli show <ProjectionId-without-version>` fails with a clear error
- The error indicates explicit version is required
- No fallback behavior occurs

## TS3-001-003 — CLI eval is replay-deterministic and replay-equivalent
**Intent**
Establish that semantic execution via the CLI is deterministic and equivalent to direct projection invocation.

**Command**
- `dipole semantic eval <ProjectionId>@<Version> --log <path>`


**Given**
- A fixed event log `L`
- A projection `P@v`

**Expect**
- Running `eval P@v --log L` multiple times yields byte-for-byte identical output
- Output is identical to direct invocation of `P(L)` after canonical encoding
- Stdout contains only the result
- Stderr is empty on success
- Exit code is `0` on success

**Notes**
- Execution is explicit and opt-in
- Canonical encoding is part of the contract
- `list` / `show` remain introspection-only
- This slice introduces **semantic execution**, not registry access

---

## Invariants Preserved Across TS3
- Consumers never infer or select versions implicitly
- Canonical JSON is the external semantic contract
- CLI remains registry-driven and deterministic
- Any defaults or ergonomics live above TS3

---

### TS3-001-004 — Unknown ProjectionId fails safely
**Given**
- A ProjectionId not present in registry

**Expect**
- `cli show` fails with “unknown ProjectionId”
- No partial execution, no implicit substitution, no fallback

---

## TS3-010 — Projection Feed (Pub/Sub)

**Intent:** Prove downstream-only distribution of semantic frames keyed by `ProjectionId`,
replay-equivalent to direct projection, with no raw event subscription capability.

> Note: these tests intentionally avoid testing “transport” details.
> The feed may initially be an in-process API; later it may be backed by channels/queues.
> The tests assert behavior, not implementation.

### TS3-010-001 — Feed frame identity is keyed by ProjectionId
**Given**
- A feed configured to publish frames for a set of ProjectionIds `{P1@v, P2@v, ...}`

**Expect**
- Every published frame includes the originating `ProjectionId`
- Frames cannot exist without a ProjectionId

### TS3-010-002 — Feed is replay-equivalent to direct projection
**Given**
- A fixed log `L`
- Feed configured for `P@v`

**Expect**
- The last frame published by feed for `P@v` equals `P@v(L)`
- Rebuilding feed from scratch over `L` produces the same final frame

### TS3-010-003 — Feed publishes only derived meaning (no raw event subscription)
**Given**
- A consumer attempts to subscribe to raw events via the feed API

**Expect**
- The API does not exist, or returns an explicit “unsupported”
- No test path can access raw events through TS3 distribution primitives

### TS3-010-004 — Feed version opt-in is enforced
**Intent**
Prove that TS3 feed consumers must explicitly opt in to a projection version, and that no implicit “latest” or ambiguous resolution is permitted.

This test locks in the rule that:
- version is part of projection identity
- ambiguity is a hard failure, not a convenience default

**Given**
- Two versions of same projection exist `P@v1`, `P@v2`
- Consumer subscribes to `P` without specifying version

**Expect**
- Feed operation fails clearly and deterministically
- Failure indicates version ambiguity or missing version
- No implicit “latest” version is selected
- No Frame is produced
- No ambiguous or partially derived output is returned

**Test outline (suggested)**
- Register projections `P@v1` and `P@v2`
- Invoke feed with an unversioned ProjectionId ("`P`")
- Assert:
  - error is returned
  - error is specific (e.g. UnknownVersion or equivalent)
  - no Frame allocation occurs

**Notes**
- This is a consumer-facing semantic invariant
- Unlike TS3-010-003, this rule is enforced via runtime validation
- This test prevents accidental coupling to registry ordering or future “latest” shortcuts

### TS3-010-005 — Multi-projection feed isolation
***Status*** Deferred

***Rationale:***
- Current TS3 feed API is functional and pull-based
- No subscriber or routing abstraction exists yet
- Isolation is enforced structurally by call-site selection and ProjectionId tagging
- This invariant is already covered by TS3-010-001

This test will be activated once a true pub/sub or subscriber layer is introduced.

**Given**
- Feed configured for `P1@v` and `P2@v`
- Subscriber requests only `P1@v`

**Expect**
- Subscriber receives only frames for `P1@v`
- No leakage / mixing across ProjectionIds

---

## TS3-UI-001 — REPL & tmux Reintroduction (Read-Only Consumers)

**Intent:** Prove that UI surfaces remain strict consumers of the feed, with no authority.

> Note: these tests should be written at the boundary of “UI adapter” modules,
> not against tmux itself. The key is to prove *read-only consumption semantics*.

### TS3-UI-001-001 — UI subscribes to feed and renders frames
**Given**
- A feed capable of producing `Frame{ projection_id = P@v, payload = … }`
- A UI adapter configured for **that same** `P@v`

**Expect** (what this test must prove, not assume)
1. Consumption only
- Adapter receives a `Frame`
- Adapter produces a render output (string or render model)
2.No projection authority
- Adapter does not call any projection function
-Adapter does not rebuild state from events
-Adapter does not accept an event log
3. No raw access
- Adapter cannot observe or pattern-match on events
- Adapter cannot downcast or escape the Frame abstraction
4. Version strictness
- Adapter fails if Frame’s `ProjectionId@version` does not match configuration
- No “latest”, no fallback, no coercion

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

### TS3-UI-001-003 — UI is replay-equivalent (rendered output stable under replay)
**Given**
- A fixed event log `L`
- A ProjectionId `P@v`
- A UI adapter configured for `P@v`

Two independent runs
1. Run A
- Build feed from `L`
- Produce `Frame(P@v)`
- Pass frame to UI adapter
- Capture `RenderOutput A`

2. Run B
- Rebuild feed _from scratch_ over the same `L`
- Produce `Frame(P@v)`
- Pass frame to a _fresh UI adapter instance_
- Capture `RenderOutput B`

**Expect**
- `RenderOutput A == RenderOutput B` (deep equality)

---

## Acceptance Summary (TS3)

TS3 is complete when tests collectively prove:

- Contract drift is prevented before exposure (TS2-003)
- A minimal consumer can safely list/show meaning (TS3-001)
- Meaning can be distributed downstream-only via frames (TS3-010)
- UI can be reintroduced as a strict consumer (TS3-UI-001)
- No authority, execution, or raw event access has entered the system

---

## TS3 Locked Contract (Normative)

This section records the **normative, locked-in contract** for TS3.
All TS3 implementation and tests MUST conform to these rules.
Changes require an explicit architectural decision and revision of this section.

---

## Projection Identity

### ProjectionId
- A stable semantic name
- Non-empty
- Must NOT start with `.`
- Allowed characters: `A–Z a–z 0–9 _ . -`
- Forbidden characters: whitespace, `@ : # ? & /`

ProjectionId identifies *meaning*, not implementation or version.

### Version
- Numeric type: `u32`
- Version selection is **mandatory and explicit**
- No implicit “latest” version exists

### Registry Identity
- Projections are identified by the pair: `(ProjectionId, Version)`
- Multiple versions of the same ProjectionId may coexist
- Registry is declarative and inert

### Ordering
- Sorted lexicographically by `ProjectionId`
- Then sorted numerically by `Version`

---

## CLI Contract

### Selector Syntax
- Canonical form: `foo@2`
- Accepted sugar: `foo@v2`
- Parsed internally as `{ ProjectionId, Version }`

### `list`
- Outputs `(ProjectionId, Version)` pairs
- Deterministic ordering per registry ordering rules
- Listing does NOT execute projections

### `show`
- Requires explicit ProjectionId + Version
- Executes the selected projection exactly once
- Output is canonical JSON (see below)

### Exit Codes
- `0` — success
- `2` — usage error (e.g. missing version)
- `3` — unknown ProjectionId or Version
- `1` — other runtime errors

### Error Tokens (stderr)
The following tokens MUST appear verbatim for test assertions:
- `ERR_MISSING_VERSION`
- `ERR_UNKNOWN_PROJECTION_ID`
- `ERR_UNKNOWN_VERSION`

---

## Canonical JSON Output

Projection outputs consumed by TS3 MUST be serializable to canonical JSON.

### Allowed Types
- object (string keys only)
- array
- string
- integer (base-10, no leading zeros except `0`, optional leading `-`)
- boolean
- null

### Disallowed Types
- floating point numbers
- binary blobs
- NaN / Infinity
- implementation-specific encodings

### Serialization Rules
- Object keys sorted lexicographically by UTF-8 byte order
- Deterministic array ordering (projection responsibility)
- Compact encoding (no spaces or newlines)
- Identical semantic output MUST produce identical bytes

---

## Projection Contract Drift (TS2-003)

- Drift tests assert **functional equality and determinism only**
- No allocation counting or instruction budgeting
- `permitted_fields` are surfaced via registry metadata
- Synthetic event-pair tests verify semantic non-dependence
- No runtime instrumentation or reflection

---

## Projection Feed (TS3-010)

### Frame Schema
Projection feed frames are **snapshots**, not deltas:

```text
{
  projection_id,
  projection_version,
  seq_end,   // inclusive
  payload
}
```

### Checkpoint Semantics
- `seq_end` is inclusive: the last event applied
- No `seq_start` exists in TS3
- Empty event log produces `no frames`

### Feed Properties
- Downstream-only
- Replay-deterministic
- Rebuildable from the event log
- No raw event subscriptions
- No timestamps or hashes

### Access Model
- Pull-based APIs (`get_frame`, `get_frame_at(seq_end)`)
- Historic frames obtained via deterministic rebuild
- Subscription errors follow CLI error tokens and exit codes

## UI Consumer Contract (TS3-UI-001)
UI surfaces are strict, non-authoritative consumers.

### Render Model
UI adapters consume frames and produce a deterministic render model:
```txt
{
  title,
  sections?: [
    {
      title?,
      rows: [
        { label, value }
      ]
    }
  ]
}
```
- `value` is a pre-formatted string
- Ordering is meaningful and deterministic
- If `sections` is absent, a single implicit section is assumed

### Constraints
- No colors, widths, wrapping, or layout decisions
- No command issuing or execution control
- No event log mutation
- UI is replay-equivalent under rebuild

## Event Metadata Exposure
- Log position metadata (e.g. `seq_end`) MAY be exposed
- Raw event payloads MUST NOT be exposed via TS3
- TS3 MUST NOT provide a backdoor for raw event subscription

## Invariants (Restated)
Across all TS3 mechanisms:
  - Event log append remains the only ingest path
  - Projections remain pure and replayable
  - Consumers reference meaning by ProjectionId + Version only
  - Version opt-in is explicit
  - Dataflow is downstream-only
  - No execution authority exists in TS3

---

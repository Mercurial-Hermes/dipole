Interaction and Control (TS4)
=============================

Purpose
-------

This document defines how user intent and control enter Dipole,
following the completion of the sealed semantic pipeline (TS1–TS3).

TS4 introduces agency — the ability for a user to request action —
without violating semantic purity, replay determinism, or authority boundaries.

TS4 does not redefine meaning.
It introduces a control plane that may cause new events.

Architectural Position
----------------------

TS4 sits above and orthogonal to the semantic pipeline.

User
  ↓
Intent (TS4)
  ↓
Validation (TS4)
  ↓
Authority (Controller / Driver)
  ↓
Event Log (TS1)
  ↓
Semantic Pipeline (TS2–TS3)


TS4 treats all semantic outputs as observational only.

Preconditions (Established by TS3)
----------------------------------

Before TS4 begins, the system guarantees:

Semantic Pipeline (Sealed)

Event log is the sole replayable truth

Projections are pure and deterministic

Semantic meaning is named, versioned, and inert

Frames distribute meaning downstream-only

UI surfaces are strict, read-only consumers

No authority exists downstream of the event log.

TS4 Design Goal
---------------

Enable explicit, controlled expression of user intent
that may result in new Events —
without contaminating semantic meaning or granting authority to consumers.

This is the transition from:

“Meaning can be observed”

to:

“Intent can be expressed safely.”

Non-Goals (Explicit Exclusions)
-------------------------------

TS4 must not:

Introduce new semantic meaning

Allow consumers or UI to mutate state

Collapse intent into Events

Introduce implicit execution paths

Add planners, schedulers, or workflows (v0.2)

Reintroduce “latest” defaults or ambiguity

Break replay determinism

Core Invariants
--------------

Across all TS4 mechanisms:

Intent is not an Event

Intent is not replayed

Events remain the only replayable truth

All execution authority flows through the existing Controller / Driver boundary

Semantic pipeline remains unchanged

UI remains non-authoritative by construction

Intent
------

Definition

An Intent is an immutable, typed, versioned value representing a
user’s request for action.

Intent:

expresses desire, not fact

carries no authority by itself

has no side effects

may be rejected without consequence

Properties

An Intent MUST be:

immutable

explicitly typed

explicitly versioned

serializable (for transport, not replay)

non-authoritative

An Intent MUST NOT:

be appended to the event log

encode semantic meaning

execute actions directly

depend on raw events

Validation
----------

Validation Boundary

Intent validation is pure and deterministic.

Validation:

may read semantic state via Frames only

must not access:

Controller

Driver

Event Log

must not produce Events

must not perform side effects

Validation Outcomes

Validation results in one of:

Accepted Intent (eligible for routing)

Rejected Intent with explicit error

Failures are:

fail-fast

typed

explicit

observable only at the intent boundary

No logging or retries occur in v0.2.

Routing to Authority
--------------------

Authority Boundary

All validated intent that results in execution must flow through the
existing Controller / Driver execution membrane.

TS4 does not introduce a new executor in v0.2.

Routing Rules

UI / CLI / REPL may construct and submit intent

They must remain ignorant of:

execution mechanics

transport details

driver semantics

Authority alone decides whether and how to act

Any effect of execution must be observed only as new Events

Replay Semantics
----------------

Intent is ephemeral

Intent is not replayed

Intent is not logged in v0.2

Replay reconstructs:

effects, not choices

The Event Log remains the only replayable truth.

Minimal TS4 Scope (v0.2)
------------------------

TS4 in v0.2 supports:

exactly one minimal Intent

deliberately trivial semantics

a single end-to-end path:

User → Intent → Validation → Authority → Event → TS1–TS3 → UI


The exemplar intent exists solely to prove the architecture.

Tests (TS4)
-----------

TS4 tests are written to prove containment, not power.

**Intent:**
- Introduce explicit user intent above the semantic pipeline, enabling controlled interaction without violating semantic purity, replay determinism, or authority boundaries.

**TS4 Global Test Invariants**

Every TS4 test must preserve:
- Event log append remains the **only** way to change replayable truth
- Intent is not an Event and is **not replayed**
- Validation is pure and side-effect free
- Execution authority is confined to Controller / Driver
- Semantic pipeline (TS1–TS3) remains unchanged
- UI and consumers remain non-authoritative

**Relationship to TS3**

TS3 remains sealed and normative.

TS4:
- depends on TS3 outputs for validation only
- must not alter TS3 contracts
- must not introduce backchannels into semantics

Any TS4 change that requires modifying TS3 invariants is considered an architectural violation.

**TS4-001 — Intent Introduction & Validation**

## TS4-001-001 — Intent is a first-class, immutable value
**Given**
- An intent value `I` constructed via the TS4 intent API

**Expect**

`I` has:
- an explicit intent type
- an explicit version

`I` is immutable:
- no setter or mutation API exists

`I` does not reference:
- Event
- EventLog
- Projection
- Frame
- Controller
- Driver

**Notes**
- This test asserts shape, not behavior
- Compilation failure is an acceptable enforcement mechanism

## TS4-001-002 — Intent is not an Event
**Given**
- An intent value `I`

**Expect**
- `I` cannot be appended to the event log
- No API exists to coerce or serialize `I` as an Event
- Any attempt to treat `I` as an Event fails at compile time

**What this test proves**
- Intent and Event are structurally distinct
- Replayable truth remains event-only

## TS4-001-003 — Intent validation is pure and deterministic
**Given**
- A fixed semantic state derived from event log `L`
- A fixed intent value `I`

**When**
- Intent validation is executed twice under identical conditions

**Expect**
- Both validation results are identical (success or same error)
- No Events are appended
- No Controller or Driver interaction occurs
- No mutation of semantic state occurs

**Notes**
- Validation may read Frames only
- This test must assert absence of side effects

## TS4-001-004 — Invalid intent produces no effects
**Given**
- An invalid intent value `I_invalid`

**When**
- Validation is executed

**Expect**
- Validation fails with an explicit, typed error
- No Events are appended
- No execution path is triggered
- Semantic outputs remain unchanged

**Notes**
- Failure is fail-fast
- No logging or retries occur

## TS4-001-005 — Valid intent does not execute by itself
**Given**
- A valid intent value `I_valid`
- No authority routing invoked

**When**
- Validation succeeds

**Expect**
- No Events are appended
- No execution occurs
- No semantic output changes

**What this test proves**
- Intent carries no authority
- Validation alone cannot cause effects

**TS4-002 — Intent Routing & Authority**

## TS4-002-001 — Valid intent routed to authority may produce Events
**Given**
- A valid intent value `I_valid`
- A Controller / Driver configured to accept this intent
- A fixed initial event log `L`

**When**
- `I_valid` is routed explicitly to the Controller

**Expect**
- Zero or more **new Events** are appended to the event log
- New Events appear after the last event in `L`
- No other mutation path exists

**Notes**
- Event contents are not asserted here
- Only the existence and ordering of new Events matters

## TS4-002-002 — Effects of intent are observable only via Events
**Given**
- Two runs:
  - Run A: intent routed, Events appended
  - Run B: identical event log reconstructed without intent

**When**
- Semantic pipeline (TS2–TS3) is executed over both logs

**Expect**
- Semantic outputs differ _only if_ Events differ
- No semantic output depends on the presence or absence of intent

**What this test proves**
- Replay reconstructs effects, not choices
- Intent is observationally irrelevant once Events exist

## TS4-002-003 — Intent is not replayed
**Given**
- An event log `L` produced after routing intent `I`
- A fresh system instance with no intent history

**When**
- Semantic pipeline is rebuilt from `L`

**Expect**
- Semantic outputs match the original run
- No intent validation or execution occurs during replay
- Replay requires Events only

**TS4 Scope Guard**

## TS4-900-001 — TS4 introduces no new semantic meaning
**Given**
- The projection registry before TS4
- The projection registry after TS4

**Expect**
- No new projections are registered
- No existing projections are modified
- No new `permitted_fields` appear

**Notes**
This test guards against semantic leakage from TS4

___

**Acceptance Summary (TS4)**

- TS4 is complete for v0.2 when tests collectively prove:
- Intent exists as a distinct, non-authoritative concept
- Validation is pure and deterministic
- Execution authority remains confined
- All effects are expressed as Events
- Replay determinism is preserved
- TS1–TS3 invariants remain untouched

**Summary**

TS4 introduces agency without corruption.
- It allows Dipole to move from:
  - “I can observe what happened”
  - to:
  - “I can ask for something to happen — explicitly, safely, and audibly.”

All meaning remains downstream.
All authority remains upstream.
All effects flow through the event log.

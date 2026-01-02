# Architectural Invariants (Non-Negotiable)

## Purpose

This document defines the **architectural invariants of Dipole**.

These are not preferences, patterns, or guidelines.
They are **hard constraints** that exist to:

- prevent architectural drift
- preserve replayability and pedagogy
- keep the system legible over long time horizons
- constrain both human and AI contributors

Any change that violates an invariant is **architecturally incorrect**, even if it works.

This document must be read **before** proposing or writing code.

---

## Invariant 1 — Truth Is Immutable

All truth in Dipole is immutable.

- Events are append-only
- Snapshots are immutable
- Ordering is authoritative
- History is never rewritten

No module may mutate past truth.

If something appears to “change”, it must be represented as a **new event**.

---

## Invariant 2 — The DebugSession Is the Kernel

The DebugSession is the **unit of meaning** in Dipole.

It is:
- the authoritative record of what happened
- backend-agnostic
- replayable
- immutable

Everything else exists to:
- create a DebugSession
- project a DebugSession
- learn from a DebugSession

No other module may become a hidden source of truth.

---

## Invariant 3 — Single Ingress Boundary

All external reality enters Dipole through a **single ingress boundary**.

For live debugging, this boundary is the **Controller**.

- Only one module may read/write the debugger transport
- Only one module may admit observations as Events
- Ordering is enforced at ingress

Multiple readers, side channels, or “temporary shortcuts” are forbidden.

---

## Invariant 4 — Controller Is Not an Interpreter

The Controller is a **routing and admission boundary**, nothing more.

The Controller:
- sends commands outward
- captures observations inward
- preserves order
- admits events

The Controller must **never**:
- parse debugger output
- infer execution state
- recognise prompts semantically
- suppress, coalesce, or reorder observations
- “improve” or “clean up” reality

Interpretation belongs elsewhere.

---

## Invariant 5 — CLI Is Not the System

The CLI is an interface, not an authority.

The CLI:
- parses user input
- expresses intent
- wires components together

The CLI must **never**:
- talk directly to a debugger
- own debugger transports
- emit events
- become a controller surrogate
- accumulate business logic

`main.zig` must remain thin and structural.

---

## Invariant 6 — Derived State Is Disposable

All derived state is:
- ephemeral
- reconstructible
- discardable

Deleting derived state must not affect correctness.

If correctness depends on derived state, the architecture is wrong.

---

## Invariant 7 — Semantics Never Emit Truth

Semantic derivation:
- explains
- annotates
- narrates

It must **never**:
- emit events
- mutate truth
- influence execution
- become required for correctness

Truth exists without explanation.

---

## Invariant 8 — Direction of Dependency Is Sacred

Dependencies flow **one way only**:

ExecutionSource → Controller → DebugSession → Derived State → Semantics → UI

Downward dependencies are forbidden.

If a module “needs” to look downward, the design is incorrect.

---

## Invariant 9 — Raw First, Meaning Later

Dipole always records **raw observation first**.

Meaning is layered on later.

Any attempt to:
- pre-classify output
- discard “noise”
- collapse events early

is a violation of epistemic discipline.

---

## Invariant 10 — Architecture > Convenience

Short-term convenience must never override architectural clarity.

Especially forbidden rationales:
- “we’ll clean it up later”
- “this is just temporary”
- “it’s easier this way”
- “the user can’t tell”

Dipole is designed for **long-term understanding**, not short-term speed.

---

## Enforcement Rule

If a proposed change:
- cannot be explained using `interaction-flow.md`
- violates any invariant above
- blurs responsibility boundaries

then the correct response is **not to implement it**.

Architecture comes first.
Always.

---

## Final Reminder

Dipole is not just a debugger wrapper.

It is a **truth-preserving system for understanding execution**.

These invariants exist so that:
- recorded sessions remain meaningful years later
- pedagogy remains possible
- complexity does not collapse the system

Break these invariants, and Dipole stops being Dipole.

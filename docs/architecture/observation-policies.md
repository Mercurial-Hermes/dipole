
Policies are **purely reactive**.

---

## What Observation Policies ARE Allowed To Do

An Observation Policy MAY:

- read immutable Events from the DebugSession
- track its own ephemeral internal state
- decide *when* to issue a command
- issue commands **only via the Controller**
- be enabled or disabled explicitly by the UI
- exist in multiple instances concurrently

Examples (conceptual, not prescriptive):

- “When execution stops, request a register dump”
- “After each step, request disassembly”
- “On breakpoint hit, request backtrace”

These are **policies**, not semantics.

---

## What Observation Policies MUST NOT Do

An Observation Policy MUST NOT:

- parse or interpret debugger output
- inspect raw LLDB transport bytes
- infer meaning from payload contents
- classify events semantically
- mutate DebugSession internals
- emit Events directly
- update UI state
- depend on UI concepts (panes, layout, tmux)

If a policy needs interpretation, that logic belongs in:
- **Derived State**, or
- **Semantic Derivation**

Not here.

---

## Relationship to the Controller

Observation Policies do **not** talk to LLDB.

They interact with the system only by:

- issuing command requests to the Controller
- using the same routing mechanisms as user intent

The Controller:
- does not know *why* a command was issued
- does not distinguish user vs policy commands semantically
- remains a pure routing and ingress boundary

---

## Relationship to the CLI / UI

The UI (CLI, tmux, Dojo):

- enables or disables policies
- chooses which policies are active
- renders results of policy-triggered commands

The UI:
- does not contain policy logic
- does not infer when commands should run
- does not inspect Events to make decisions

Policies are **headless**.

---

## Relationship to tmux

tmux panes are **views**, not actors.

In particular:

- tmux panes do not poll the debugger
- tmux panes do not auto-issue commands
- tmux panes do not contain timing or condition logic

Any “automatic refresh” behaviour must live in an Observation Policy,
never in tmux scripts or pane glue code.

---

## Determinism and Replay

Observation Policies:

- may be disabled during replay
- or re-run deterministically from the event log

Because policies:
- observe Events
- issue commands through the Controller
- and do not mutate truth

their effects are **replayable or suppressible by design**.

---

## Non-Goals

This document does NOT:

- define policy APIs
- define scheduling or threading
- define configuration formats
- introduce semantics or snapshots
- describe implementation details

Those emerge later, under test pressure.

---

## Architectural Guardrails (Non-Negotiable)

Violations of this document include:

- Controller interpreting output to trigger commands
- CLI issuing commands “when something happens”
- tmux panes containing automation logic
- DebugSession embedding policy decisions
- Semantic derivation issuing commands

Any such change is an architectural error.

---

## Summary

Observation Policies are the **only place** where automated behaviour is allowed.

They:
- observe truth
- issue commands
- remain ignorant of meaning
- preserve Controller and CLI purity

This boundary exists so Dipole can grow interactive, automated,
and pedagogical — **without losing coherence**.

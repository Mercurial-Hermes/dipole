# PROJECT_START.md

## Purpose

This document answers:
“What does Dipole v0.2.4 do, exactly, and why is it structured this way?”

It is a **current-state** description, not a roadmap.

---

## What Dipole Is (v0.2.4)

Dipole is a disciplined, event-sourced wrapper over LLDB for pedagogical use.

It provides:
- one long-lived LLDB session per Dipole session
- a Dipole-owned REPL as the sole source of user intent
- view-only panes that render projection output
- explicit snapshot requests (`regs`, `snapshot regs`)
- raw snapshot payloads recorded as immutable events
- deterministic replay at the event and projection level

Raw LLDB output is logged but never treated as authoritative truth.

---

## Architectural Shape (Why It Is This Way)

Dipole is structured to preserve replayability and avoid semantic leakage:

- **DebugSession** is append-only and immutable.
- **Controller** is the sole LLDB transport owner.
- **Observation Policies** are static and declarative.
- **Projections** are pure, deterministic, and downstream-only.
- **UI panes** consume projections only and never touch the kernel or transport.

This keeps truth acquisition, interpretation, and presentation strictly separated.

---

## What Dipole Does *Not* Do (v0.2.4)

Explicit non-capabilities:
- no parsed registers
- no semantic interpretation
- no execution state modeling
- no stop-reason inference
- no breakpoint projections
- no replay UI
- no persistence layer

These are intentional constraints, not omissions.

---

## Guiding Contract

Dipole must never:
- parse LLDB output in the kernel or Controller
- infer meaning upstream of projections
- allow UI to bypass the Controller
- mutate events after admission

When in doubt, it stops and asks.

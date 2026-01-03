# PROJECT_STATE.md

## Purpose

This document records the **current architectural and implementation state of Dipole**.

It exists to:
- anchor shared understanding across long development cycles
- prevent accidental regression into ad-hoc control flow
- give Codex (and humans) a reliable “where are we now?” reference
- make it safe to pause, resume, and refactor without losing intent

This is **not** a roadmap.
It is a snapshot of truth.

---

## Architectural Status (Authoritative)

Dipole v0.2 architecture is now **actively enforced in code**.

The following documents are authoritative and must be read together:

- `docs/architecture/architectural-invariants.md`
- `docs/architecture/dipole-module-boundary.md`
- `docs/architecture/interaction-flow.md`
- `docs/architecture/debug-session.md`
- `AGENTS.md`

If a change cannot be explained using these documents, it does not belong in the core.

---

## What Is Working (Confirmed)

### 1. Controlled LLDB Interactive Session

Dipole now supports a **controlled, architecture-compliant interactive LLDB session**.

Key properties:
- The Controller is the **sole owner** of the LLDB PTY
- The CLI never reads or writes debugger transports
- All externally observed effects are admitted as immutable Events
- Event ordering is deterministic and monotonic
- Raw backend output is preserved without interpretation

This is a genuine step forward: Dipole now *observes* debugging rather than *performing* it ad-hoc.

---

### 2. v0.2.3 Gate 1 — Long-Lived Session + REPL Ownership (Complete)

- one long-lived LLDB process per session
- Dipole-owned REPL as the sole source of user intent
- LLDB output logged only, never rendered directly

---

### 3. v0.2.3 Gate 2 — Pane Role Migration (Complete)

Non-REPL panes are now pure view processes:
- no command pipe access
- no backend output draining
- no transport ownership

Backend output logging is centralized and pane-independent.

---

### 4. v0.2.3 Gate 3 — Snapshot Events (Complete)

Register snapshots are now captured as Snapshot Events:
- emitted only after execution commands (step-in, step-over, continue)
- raw backend bytes stored without parsing
- anchored to prior event sequence boundaries

Snapshot admission is append-only and kernel-owned.

---

### 5. v0.2.3 Gate 4 — Projection Layer (Complete)

- projections compute deterministic views from immutable events
- register snapshot projection selects the latest snapshot event
- right pane consumes projection output only
- kernel access remains single-threaded

---

### 6. Clear Boundary Between CLI, Controller, and DebugSession

Boundaries are now explicit and enforced:

**CLI**
- Reads argv and stdin
- Validates syntax
- Expresses intent
- Owns stdin/stdout rendering
- Does *not* talk to LLDB
- Does *not* admit events

**Controller**
- Sole ingress/egress for debugger transport
- Routes intent downward
- Admits raw observations upward as Events
- Preserves order
- Does not interpret output
- Does not render UI

**DebugSession**
- Immutable, append-only event log
- Payload ownership is explicit
- Replay from events alone is supported
- No semantics, no UI, no execution control

These roles now match the architecture documents exactly.

---

### 7. Event-Sourced Core Is Exercised by Tests

The test suite now validates key invariants:

- Intent validation produces no side effects
- Execution effects are observable **only** via events
- Replay from an event log reproduces semantic output
- Controller admits raw observations without interpretation
- Event ordering and identity are preserved

This is not cosmetic coverage — it exercises the architectural heart.

---

## Current Code Shape (High-Level)

### `cmd/dipole/main.zig`
- Thin wiring only
- Argument parsing
- Dispatch into CLI modules (e.g. attach session)
- No debugger logic
- No polling
- No PTY access

### `cmd/dipole/cli/attach_session.zig`
- CLI entrypoint only
- Argument parsing and dispatch

### `cmd/dipole/cli/attach_session_impl.zig`
- Attach lifecycle orchestration
- Controller loop + projection loop
- Pipe setup for REPL and view panes
- Does not interpret backend output

### `lib/core/controller.zig`
- Broker loop for command ingress + observation ingestion
- Talks to Driver only
- Admits all observations as Events
- Writes raw output to pipes (not stdout)
- No parsing, no semantics

### `lib/core/debug_session.zig`
- Immutable event log
- Explicit payload ownership
- Replay supported
- Kernel remains small and defensible

---

## What Is Explicitly *Not* Implemented Yet

This is intentional.

- No semantic interpretation of LLDB output
- No register parsing
- No prompt detection
- No stop detection or inferred execution state
- No multi-threaded kernel access

These are **next-layer concerns**, not missing features.

---

## Identified Next Architectural Pressure Point

### Observation Policies Beyond Mechanical Snapshots

Observation scheduling beyond post-command snapshots remains intentionally minimal.

---

## Approved Direction (Pending Implementation)

The request envelope on the command pipe is now formalized in
`docs/architecture/request-routing.md`.
It remains a transport-only boundary and does not change intent semantics.

---

## Known Risks (Actively Managed)

- Controller creeping into interpretation
- UI filtering backend output
- Short-circuiting DebugSession for convenience
- Adding “helpful” parsing too early
- Allowing tmux panes to touch LLDB directly

All of these have been explicitly identified and are being guarded against.

---

## Overall Assessment

Dipole is now **architecturally coherent** for v0.2.3.
The release adds a long-lived session, a Dipole-owned REPL, snapshot events,
and a projection-driven view pane, with raw LLDB output preserved in logs only
and never rendered directly to the user.

We have:
- regained control over boundaries
- aligned code with design documents
- proven the event-sourced core with tests
- created space for UI and pedagogy without corruption

This is a **stable platform** to build tmux-based observation next — carefully.

---

## Guiding Principle Going Forward

> When in doubt:
> - pause
> - write it down
> - ask whether it belongs above or below the intent boundary

Understanding is the product.  
Execution is just the substrate.

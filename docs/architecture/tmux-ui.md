# tmux UI Wiring (Phase 0)

## Purpose

Describe the **minimal and strictly non-semantic** tmux wiring used to host
multiple UI panes **without changing** Controller, Driver, or DebugSession
semantics.

This document defines **wiring only**:
- no interpretation
- no parsing
- no semantics
- no policy

If behaviour appears to change, the architecture has been violated.

---

## Constraints (Hard Invariants)

The following constraints are **architectural invariants**:

- Controller is the **sole owner** of the LLDB PTY.
- Panes **never** talk to LLDB directly.
- All commands flow **only** through the request envelope.
- All output flows **only** from the Controller through pipes.
- CLI remains the **intent boundary**.

These constraints are not guidelines.  
They are required for correctness.

---

## Wiring Model

Two pane processes are spawned under tmux:

- **Left pane**: interactive REPL
- **Right pane**: raw output view

Each pane:

- reads stdin
- writes request envelopes to a **shared command pipe**
- reads from its **own output pipe**
- writes raw bytes to stdout

The Controller:

- reads envelopes from the command pipe
- forwards payloads to the Driver **unchanged**
- fans out LLDB output **identically** to all output pipes

No routing, filtering, or interpretation occurs at this layer.

---

## Module Layout (Phase 0)

- `cmd/dipole/ui/pane_runtime.zig`
  - pane loop only (stdin → envelope, output pipe → stdout)
  - no Controller, no tmux knowledge
- `cmd/dipole/ui/tmux_session.zig`
  - tmux session orchestration and pane spawning
  - no pipe polling, no protocol logic
- `lib/core/transport/request_envelope.zig`
  - envelope framing (source_id + length + payload)
  - transport-only
- `lib/core/transport/fd_utils.zig`
  - file descriptor helpers (pipes, CLOEXEC, nonblocking)

Controller, Driver, and DebugSession semantics remain unchanged.

---

## Why tmux Is Architecturally Acceptable

tmux is used **only** for process orchestration.

Panes are independent CLI processes that:

- express intent (stdin → command envelope)
- render raw output (output pipe → stdout)

tmux lives **above the intent boundary** and does not introduce:

- authority
- meaning
- interpretation
- policy

If tmux appears to “add features”, that is a design error.

---

## Pane Roles (Phase 1)

Pane roles are **UI-only metadata** provided at pane startup:

- `repl`
- `output`

Roles:

- do not affect envelopes or payload bytes
- do not affect Controller routing
- do not affect output content

Roles may only influence local UI behavior (e.g., a static banner).

---

## Forbidden Patterns (Enforced by Design)

tmux panes and wiring MUST NEVER:

- parse LLDB output or detect prompts
- infer execution state or semantic meaning
- route based on payload contents
- bypass the Controller or talk to LLDB directly
- emit Events or mutate DebugSession state
- implement policy, automation, or heuristics
- use pane roles to suppress, filter, or redirect output

If any of these appear, the architecture has already failed.

---

## Future Panes (e.g. Registers, Memory)

Phase 0 panes are **transport-only**.

Any future semantic panes MUST:

- be driven by **Events or Snapshots**, not raw output
- never infer meaning directly from LLDB bytes
- remain strictly **above the intent boundary**
- be testable without tmux

Semantic elevation happens **once**, at the Controller boundary — nowhere else.

---

## Lifecycle & Failure Semantics

- Pane exit is tolerated; no UI state recovery is guaranteed.
- Controller authority is unaffected by UI process lifetime.
- tmux provides **no guarantees** about output completeness or ordering beyond
  what the Controller emits.

Lossiness at the UI layer is acceptable by design.

---

## Testing Expectations

The following are explicitly testable invariants:

- request envelopes round-trip unchanged
- Controller fans out identical output to all sinks
- pane runtime does not parse, interpret, or branch on payload content
- tmux orchestration contains **no protocol logic**

No tmux integration tests are required or desired.

---

## Non-Goals

- No output parsing or prompt detection
- No register interpretation
- No snapshot semantics
- No routing based on payload content

---

## Compatibility

Single-pane `dipole attach --pid <pid>` remains unchanged.

---

# tmux UI Wiring (v0.2.3)

## Purpose

Describe the tmux wiring used to host a Dipole-owned REPL and view panes
**without changing** Controller, Driver, or DebugSession semantics.

This document defines **wiring only**:
- no interpretation in the Controller
- no parsing of LLDB output in UI panes
- no policy in tmux glue

If behaviour appears to change, the architecture has been violated.

---

## Constraints (Hard Invariants)

The following constraints are **architectural invariants**:

- Controller is the **sole owner** of the LLDB PTY.
- Panes **never** talk to LLDB directly.
- All commands flow **only** through the request envelope.
- Raw LLDB output is **never** shown directly to the user.
- Raw LLDB output is preserved in logs only.
- The Dipole REPL is the **sole user command interface**.
- CLI bootstraps the session and wires components; it does not execute commands.

These constraints are not guidelines.  
They are required for correctness.

---

## Wiring Model

Two pane processes are spawned under tmux:

- **Left pane**: interactive REPL
- **Right pane**: read-only semantic view (e.g. registers)

The REPL pane:

- reads stdin
- writes request envelopes to the command pipe

View panes:

- do not read stdin for commands
- render derived/semantic views only

The Controller:

- reads envelopes from the command pipe
- forwards payloads to the Driver **unchanged**
- admits raw LLDB output as Events

No routing, filtering, or interpretation occurs at this layer.

---

## Module Layout (Phase 0)

- `cmd/dipole/ui/pane_runtime.zig`
  - pane loop only (REPL intent input, view rendering)
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

- express intent only in the REPL pane
- render derived/semantic views only

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
- render raw LLDB output

If any of these appear, the architecture has already failed.

---

## Future Panes (e.g. Registers, Memory)

View panes are **projection-driven**.

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

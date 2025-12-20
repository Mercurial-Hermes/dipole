# Dipole Thin Slice – Test Ledger

## Passing Tests

TS0-001 DebugSession append preserves order + assigns monotonic seq ids
Anchors: event-sourced truth, replay determinism
Types touched: Event, DebugSession
No dependencies: controller/driver/repl/tmux/derived/semantic
Tests:
- kernel-assigned sequence identity (`seq`)
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
- Events are appended in order with deterministic, monotonic `seq`
- identical inputs produce identical event logs on replay
Tests:
- Controller → Driver interaction produces tx, rx, prompt observations
- no observations are dropped, reordered, or synthesised
- event sequence is replay-equivalent
Status: ✅ Passing
Notes:
- events represent transport-level observations only
- no parsing, interpretation, or semantic meaning is introduced


## Next Test (RED)

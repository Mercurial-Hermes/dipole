Samples

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

## Next Test (RED)

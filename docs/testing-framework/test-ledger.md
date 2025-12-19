Samples

# Dipole Thin Slice – Test Ledger

## Passing Tests



## Next Test (RED)

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

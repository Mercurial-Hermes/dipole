Samples

# Dipole Thin Slice – Test Ledger

## Passing Tests

### [CORE] DebugSession records ordered events
- Given a new DebugSession
- When two events are appended
- Then they are stored in order
- Status: PASS

### [CORE] Snapshot is immutable once created
- Given a Snapshot
- When attempting mutation
- Then mutation is impossible
- Status: PASS

### [INTERACTION] Controller routes Run intent to ExecutionSource
- Given a Controller with a FakeExecutionSource
- When CommandIntent.Run is issued
- Then ExecutionSource receives Run request
- Status: PASS

---

## Next Test (RED)

### [INTERACTION] Live ExecutionSource emits StopEvent after Run
- Status: NOT IMPLEMENTED

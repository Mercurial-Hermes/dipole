# Snapshot Event Schema — Review Checklist (Gate 3)

This checklist defines the **non-negotiable requirements** for introducing
Snapshot Events into Dipole.

It must be satisfied **before** any snapshot-related code is merged.

If any item cannot be answered clearly, **stop and ask**.

---

## 1. Purpose & Scope

### ☐ Is the snapshot’s purpose observational, not semantic?

A Snapshot Event must answer:

> “What was observed at this moment?”

It must **not** answer:
- why it happened
- what it means
- whether it is important

If the snapshot implies meaning, it is misplaced.

---

### ☐ Is the snapshot explicitly tied to a moment in the event stream?

Every snapshot must be anchored to **existing truth**, not free-floating.

Acceptable anchors:
- after event sequence N
- after command event X
- at replay position Y

Unacceptable:
- when execution stopped
- when registers changed

---

## 2. Event Model Compliance

### ☐ Is the snapshot represented as an Event (not state)?

Snapshots must be:
- append-only
- immutable
- replayable

If the snapshot is stored in mutable session state, it violates the kernel.

---

### ☐ Does the snapshot live in the core event model?

Snapshot payloads must live alongside:
- command events
- backend events
- execution events

If the payload is UI-owned or Controller-owned, it is incorrect.

---

### ☐ Is the snapshot payload backend-agnostic?

Even if LLDB is the only backend today:
- payload structure must not depend on LLDB internals
- interpretation must not be required to store it

Backend specificity belongs in projections, not in the event.

---

## 3. Payload Integrity

### ☐ Is the payload raw and uninterpreted?

For v0.2.3:
- payload bytes must be verbatim backend output
- no parsing
- no tokenization
- no struct fields for registers yet

If you see parsing code, stop.

---

### ☐ Is payload ownership explicit?

The schema must make clear:
- who captured it
- when it was captured
- why it was captured

At minimum:
- snapshot_kind
- source_id
- captured_at_event_seq
- payload_bytes

Implicit context is not allowed.

---

### ☐ Is the payload immutable after capture?

No mutation.
No refresh.
No overwrite.

If mutation is required, the design is wrong.

---

## 4. Trigger Semantics

### ☐ Is the snapshot trigger mechanical, not inferred?

In v0.2.3, snapshots must be triggered by:
- command completion boundaries
- explicit snapshot requests

They must not be triggered by:
- parsing backend output
- detecting stop states
- heuristics

Triggering logic belongs outside the event.

---

### ☐ Can the snapshot be absent?

Silence must be acceptable.

If the design assumes a snapshot must exist after every command, it is lying
about reality.

---

## 5. Separation of Concerns

### ☐ Does the Controller remain ignorant of snapshot meaning?

The Controller may:
- issue the raw command
- capture the bytes
- emit the event

The Controller must not:
- interpret register values
- compare snapshots
- decide importance

If it does, stop.

---

### ☐ Do UI panes consume snapshots indirectly?

Panes must:
- subscribe to projections
- never read Snapshot Events directly
- never parse payload bytes

If a pane reads snapshot payloads directly, the architecture has been violated.

---

## 6. Replay & Determinism

### ☐ Can snapshots be replayed deterministically?

On replay:
- snapshots must reappear exactly where recorded
- no new snapshots may be generated
- no commands may be reissued

If replay changes snapshot presence, it is wrong.

---

### ☐ Can projections be rebuilt using only events and snapshots?

Delete all derived state.
Restart the process.

If projections cannot be rebuilt:
- snapshot schema is insufficient
- or semantics leaked too early

---

## 7. Extensibility (Future-Proofing)

### ☐ Does the schema allow future snapshot kinds?

Today:
- registers

Tomorrow:
- stack
- memory
- threads

If adding a new kind requires changing old events, stop.

---

### ☐ Can future parsing be layered on top without changing events?

Future semantic derivation must be able to:
- parse old payloads
- re-interpret them
- attach new meaning

If parsing logic is baked into capture, you have foreclosed this.

---

## 8. Failure & Edge Cases

### ☐ What happens if snapshot capture fails?

Failure must be:
- observable
- recordable
- honest

Acceptable:
- no snapshot event
- or an error event

Unacceptable:
- silent substitution
- partial or fabricated payloads

---

### ☐ What happens if the backend emits nothing?

Silence must be preserved.

A snapshot with an empty payload is valid.
Fabricating content is not.

---

## 9. Naming & Documentation

### ☐ Is the snapshot kind name descriptive and stable?

Good:
- registers
- stack
- memory

Bad:
- state
- context
- frame_info

Names must describe what was captured, not what it means.

---

### ☐ Is the schema documented in docs/architecture/event-model.md?

If the schema exists only in code, it does not exist.

Documentation must explain:
- what the snapshot represents
- what it does not represent
- how it is consumed

---

## 10. Final Sanity Check

### ☐ Can you explain the snapshot to a learner without lying?

> “This is exactly what the debugger reported at this moment.
> We haven’t interpreted it yet.”

If you cannot say that honestly, the design is wrong.

---

## Gate 3 Rule of Thumb

Snapshots preserve reality.  
Projections derive meaning.  
Semantics explain change.

If any layer collapses into another, stop.

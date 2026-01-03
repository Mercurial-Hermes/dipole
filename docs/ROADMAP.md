# Dipole Roadmap (Truthful as of v0.2.4)

This roadmap records completed milestones, explicit deferrals, and intentionally
unspecified future work. It avoids speculative sequencing.

---

## Completed

### v0.1.0 — Interactive LLDB Wrapper
- Released
- Interactive REPL over LLDB transport
- Foundation for later architectural work

### v0.2.2 — Honest Probe Model
- Controller owns LLDB transport
- Raw observation admitted as events
- No interpretation in kernel or Controller

### v0.2.3 — Long-Lived Session + View Panes
- One long-lived LLDB session per Dipole session
- Dipole-owned REPL as sole intent source
- View-only panes consuming projections
- Raw LLDB output logged only

### v0.2.4 — Explicit Snapshot Requests
- Explicit snapshot requests (`regs`, `snapshot regs`)
- Snapshot kind as a first-class axis
- Raw snapshot payloads admitted as immutable events
- Deterministic replay at event/projection level

---

## Deferred

### Parsed Register Projections
Deferred due to missing immutable architecture metadata in the event log.
No sequencing is implied.

---

## Unspecified Future Work

Future milestones remain intentionally unspecified until they can be defined
without weakening architectural invariants.

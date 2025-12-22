# DIPOLE_GLOSSARY

A shared vocabulary for Dipole (v0.2)

This glossary defines the canonical meanings of terms used in Dipole’s code, documentation, and pedagogy. Where relevant, entries are marked as [v0.2], [historical], or [future].

---

### Event [v0.2]
An immutable record admitted into Dipole’s event log. Represents observed truth, not interpretation or intent. Core fields: `category` (e.g. snapshot, command, session), `event_id` (monotonic), `timestamp` (optional; not semantically authoritative), `payload` (opaque bytes, may be empty). Events are append-only, replayable, and the sole source of truth (TS1).

### Event Log [v0.2]
An ordered, append-only sequence of Events. Immutable once written, replayable, and the only authoritative history. All semantic meaning in Dipole is derived from the event log.

### Projection [v0.2]
Pure, deterministic function from an event log to derived meaning. Properties: read-only over events; deterministic and replayable; versioned; explicitly registered. Examples: `event.kind@1`, `breakpoint.list@1`, `register.snapshot@1`. Projections never mutate state, perform I/O, or depend on external context. (See TS2.)

### ProjectionId [v0.2]
The stable identity of a projection. Form: `<name>@<major>.<minor>`. Examples: `event.kind@1.0`, `register.snapshot@1.0`. ProjectionId + version define semantic meaning, not implementation.

### Semantic Registry [v0.2]
The authoritative catalog of all projections. Each entry declares: name, version, permitted event fields, output kind. The registry enforces version correctness, semantic drift guards, and explicit evolution.

### Frame [v0.2]
The output of a projection. Contains: `projection_id`, `version`, `payload` (opaque bytes). Frames are downstream-only, read-only, and replay-equivalent to direct projection execution. Frames are the only thing consumers may see (TS3).

### Semantic Feed [v0.2]
Distribution mechanism that produces Frames from an event log. Runs projections, emits Frames keyed by ProjectionId, does not expose raw Events, supports replay determinism. Not transport-specific in v0.2.

### Consumer [v0.2]
Any component that reads Frames. Examples: CLI commands (semantic list/show/eval/render), UI adapters, Dojo scripts. Consumers have no authority, cannot mutate state, and cannot access raw Events.

### UiAdapter [v0.2]
Boundary object that accepts Frames, enforces ProjectionId/version matching, and renders payload bytes for presentation. UiAdapters do not execute projections, do not parse or reinterpret semantics, and exist purely for presentation.

### Intent [v0.2]
A request to perform an external action. In v0.2: only `intent.ping` exists; intent is non-authoritative and produces Events, not effects directly. Intent exists to prove the control path, not to drive behavior (TS4).

### Deterministic Replay [v0.2]
Replaying the same event log yields identical Frames. This is the cornerstone of Dipole’s trust model and pedagogy.

### Snapshot Event [v0.2]
An Event whose category is `snapshot`. Carries opaque payloads and represents captured external state. Consumed by projections like `breakpoint.list@1` and `register.snapshot@1`. No semantic meaning is inferred unless a projection explicitly defines it.

### register.snapshot@1 [v0.2]
Projection that selects the most recent snapshot event, emits its payload verbatim, and emits `"[]"` if no snapshot exists. No parsing, normalization, or inference occurs in v0.2.

### breakpoint.list@1 [v0.2]
Projection that selects the most recent snapshot payload, treats payload as opaque, and emits `"[]"` if no snapshot exists.

### TS1–TS4 [v0.2]
Thin-slice milestones that define Dipole’s sealed semantic core: TS1 — Event-sourced truth; TS2 — Pure, versioned projections; TS3 — Downstream-only semantic feed; TS4 — Minimal intent plane. All four are complete and sealed in v0.2.

### LLDBDriver [historical / future]
A Zig wrapper around LLDB used in pre-v0.2 experiments. In v0.2: LLDBDriver is not part of the active architecture; LLDB is treated abstractly as an external event source. Remains relevant for historical experiments and future event ingress work.

### PTY (Pseudo-Terminal) [historical / future]
A pseudo-terminal required for interactive LLDB operation. PTY mechanics informed earlier experiments but are not part of v0.2 runtime.

### TraceSnapshot / TraceStep [historical]
Early experimental structures for PC snapshots, step deltas, timing analysis. Superseded by the event log, snapshot events, and semantic projections. Preserved as historical learning artifacts.

### Dipole Session [future]
Planned abstraction that may group events, manage debugger lifecycle, and support richer replay/visualization. Not present in v0.2.

### dipoledb [future]
Planned native backend and data store for events, traces, snapshots, performance data. Not implemented in v0.2.

### Experiment [timeless]
Small, focused investigation used to learn system behavior, document insight, and justify architecture. Experiments are permanent artifacts, pedagogical tools, and the engine of Experiment-Driven Design.

### Dojo [future / adjacent]
Educational environment built on top of Dipole’s semantic core. Dojo will script semantic outputs, teach systems concepts, and rely on v0.2 invariants for trust and clarity.

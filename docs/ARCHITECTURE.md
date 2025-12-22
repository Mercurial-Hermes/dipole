# ARCHITECTURE

## Scope of v0.2
This document describes the architecture as implemented in v0.2: a single-process CLI with TS1–TS4 sealed. Future designs and aspirations are documented elsewhere.

## Overview
Dipole’s architecture is intentionally simple and modular. It serves two parallel goals:
- practical debugging
- pedagogical clarity

We defer complexity until truly needed and document architectural decisions as they emerge. Dipole’s structure should always be something a learner can read and understand.

---

# Runtime Architecture (v0.2)

As of v0.2, Dipole is a single-process CLI. It uses LLDB only as an event source; there is no IPC layer, no tmux runtime, and no controller-driven UI refresh.

## High-level Topology
- A single process owns the LLDB PTY session and admits observations as Events.
- Semantic meaning is derived from the event log via pure projections.
- The semantic feed produces Frames keyed by ProjectionId@version.
- Consumers (CLI, adapters) are read-only and consume Frames only.

## Ownership and Invariants (v0.2)
1. Event log is the sole replayable truth (TS1).
2. Projections are pure, deterministic, and versioned (TS2).
3. Feed distributes derived Frames downstream-only; no raw events exposed (TS3).
4. UI/adapters are strict consumers of Frames; no authority or mutation (TS3).
5. Intent is minimal and non-authoritative (`intent.ping` exemplar); effects flow only as Events (TS4).

## Relationship to LLDB
In v0.2, Dipole uses LLDB as the external debugger engine for event ingress. There is no LLDB passthrough or client-side LLDB access; all downstream consumers see derived Frames only.

---

# Core Components (v0.2)

## 1. `core/` — Debugger Kernel and Semantics
This layer defines:
- Event model (categories, event_id, timestamp, optional payload)
- DebugSession (append-only event log)
- Controller/Driver boundary for raw observations
- Semantic projections and registry (e.g., `event.kind@1`, `breakpoint.list@1`, `register.snapshot@1`)
- Semantic feed producing Frames from the event log
- Minimal UiAdapter enforcing ProjectionId/version and rendering payload bytes

## 2. UI — CLI Consumers
UI in v0.2 is CLI-only. Commands cover semantic list/show/eval/render. Consumers are read-only and operate on Frames; no tmux integration or TUI exists in v0.2.

## 3. Experiments
Dipole grows through small, documented experiments. Experiments graduate into the main architecture or are retired with lessons preserved.

---

# Long-Term Architectural Principles
- Explicit over implicit — clarity creates understanding.
- Readable over clever — future learners matter.
- Isolation of OS-specific logic — portability of thought.
- Minimal dependencies — reduce cognitive overhead.
- Strong mental models — architecture teaches by example.
- Pedagogical alignment — debugging is learning.

Dipole should be a debugger you can understand by reading the code.

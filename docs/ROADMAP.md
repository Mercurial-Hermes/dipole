# 🚀 Dipole Roadmap

_A debugger, a teacher, and a node of understanding_.

Dipole is a **pedagogical debugger** for Apple Silicon systems programming.
It exists to cultivate deep understanding of program execution through clarity, structure, and carefully designed interfaces.

This roadmap outlines Dipole’s evolution from **v0.1.0 (MVP)** toward **Dipole 1.0**, balancing practical utility with long-term ambition.

---

## 🌱 Milestone 0 — v0.1.0 (MVP: Interactive LLDB Wrapper) ✅
**Status**: Released
**Tag**: v0.1.0
Dipole became alive: a functioning interactive debugger with a clean REPL and solid foundations.

**Delivered**
- PTY-driven LLDB interface with reliable prompt detection
- Non-blocking IO on macOS (Darwin PTY semantics)
- Stepping, continue, backtrace, register inspection
- Raw LLDB passthrough for escape hatches
- REPL-based interaction model
- Test-driven `LLDBDriver` foundation
- Experiments `exp0.1 → exp0.7` consolidated into stable code

v0.1.0 establishes Dipole as a **real, usable debugger wrapper**, suitable for early adopters and pedagogical exploration.

---

## 🌿 Milestone 1 — v0.2.x (Pedagogical Debugger Foundations)
**Status:** In active development
**Target:** 2026
**Tags:** v0.2.0 → v0.2.3
Dipole evolves from a thin wrapper into a **guided, screen-oriented debugger** optimised for learning.

### Core Theme
**Screen real estate as pedagogy**
v0.2.x focuses on multi-pane workflows, clarity of state, and ergonomic insight — while continuing to wrap LLDB under the hood.

### Goals
- Brokered architecture:
  - single controller owns LLDB PTY
  - serialized command execution
  - explicit session lifecycle (start → interact → quit)
- v0.2.2: honest probe model (raw observation, no interpretation)
- v0.2.3: one long-lived LLDB session per Dipole session
  - Dipole-owned REPL in the left tmux pane
  - LLDB never visible to the user
  - raw LLDB output preserved in logs only
  - right panes are view-only (starting with registers)

### Deliverables
- `v0.2.2` → probe model with strict event admission and raw output logging
- `v0.2.3` → long-lived session + Dipole REPL + view-only panes
- Updated architecture and dev-log documentation

v0.2.x is the first version where Dipole’s UX meaningfully exceeds raw LLDB for teaching and exploration.

---

## 🌾 Milestone 2 — v0.3.0 (Debugger Identity)
**Target:** Mid 2026
Dipole gains a stronger sense of identity and coherence as a debugger.

### Goals
- Cohesive command language and help system
- Stable pane layouts and navigation patterns
- Register diffing, step deltas, and execution narratives
- First structured “debugging lessons” designed explicitly for Dipole

## Deliverables
- Canonical Dipole workflows documented
- Early lesson packs that rely on Dipole features
- Tag: `v0.3.0`

---

## 🌻 Milestone 3 — v0.4.0 (Dojo Integration Phase)
**Target:** Late 2026
Dipole becomes the **engine** powering a broader learning environment.

### Goals
- Tight integration with **Dojo** (separate native macOS app)
- Lesson-driven debugging sessions
- Reproducible debugging scenarios
- Guided exploration tied to real binaries

Dipole remains open-source and terminal-centric;
Dojo provides the structured learning experience around it.

### Deliverables
- Stable Dipole ↔ Dojo integration contract
- “Systems Programming Foundations” course content
- Tag: `v0.4.0`

---

## 🌺 Milestone 4 — v0.5.0 (dipole-dbg Experiments)
**Target:** 2027
Dipole begins the transition from wrapper to engine.

### Goals
- Early `dipole-dbg` experiments:
  - attach
  - read registers
  - read memory
  - single-step
- Unified abstraction for LLDB vs native backend
- Deep documentation of Mach / AArch64 internals

### Deliverables
- First `dipole-dbg` stepping prototype
- Public design notes and feasibility reports
- Tag: `v0.5.0`

---

## 🌸 Milestone 5 — 1.0 Candidate (Integrated Learning Debugger)
**Target**: Late 2027
Dipole becomes a polished, end-to-end learning debugger.

### Goals
- Mature debugger workflows
- Rich pedagogical overlays
- Large, coherent lesson library
- Optional graphical and Metal-based visualizations
- Stable APIs and documentation

### Deliverables
- `v1.0-rc`
- Public preview and recorded demonstrations

---

## 🏆 Milestone 6 — Dipole 1.0
**Target:** 2028
A debugger.
A learning platform.
A community built around understanding.

### Deliverables
- Tag: `v1.0`
- Long-term stability guarantees
- Public launch of the Dipole ecosystem

---

## 🔭 Beyond 1.0 — The Long View
### Debugger Evolution
- Full `dipole-dbg` backend
- Advanced tracing and execution timelines
- Performance and microarchitectural insight
- Selective kernel and low-level debugging

### Dipole as a Platform
- Extensible visualizers
- Community-authored lesson packs
- Shared debugging traces and “playgrounds”

### A Learning Movement
- Quiet, disciplined systems programming culture
- Mentorship and deep-dive bootcamps
- Global community focused on craftsmanship

---

## 🧭 Roadmap Philosophy
1. **Understanding over complexity**
2. **Pedagogy over features**
3. **Depth over speed**

Dipole exists to help people learn how computers really work —
not faster, not louder, but deeper.

---

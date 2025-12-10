# 🚀 Dipole Roadmap

A debugger, a teacher, and a node of understanding.

Dipole is a native macOS debugger and learning platform for Apple Silicon. It exists to cultivate deep understanding of how computers work — through clear interfaces, guided exploration, and a supportive distributed community of learners.

This roadmap outlines Dipole’s evolution from MVP 0.1 to Dipole 1.0, including high-level milestones and long-term aspirations.

---

## 🌱 Milestone 0 — MVP 0.1 (Interactive LLDB Wrapper)
**Target:** January 2026  
Dipole becomes alive — a functioning interactive debugger with a clean REPL and pedagogical foundations.

**Goals**
- PTY-driven LLDB interface with non-blocking IO
- Stepping, breakpoints, register and memory read
- Minimal visualization prototype (PC progression)
- Foundational architecture: `LLDBDriver`, `DipoleREPL`, `DipoleRender`

**Deliverables**
- Tag: `mvp0.1`
- Developer experience clear and documented
- Experiments `exp0.1 → exp0.7` integrated into stable code

## 🌿 Milestone 1 — MVP 0.2 (Tracing + Metal Foundations)
**Target:** April 2026  
Dipole transitions from a wrapper to a guided debugger.

**Goals**
- Trace pipeline for PC, registers, stack snapshots
- Metal visualization window: instruction stepping, register deltas, execution timeline
- Internal separation of input loop, LLDB backend, visualization engine
- Initial experiments with embedding Ghostty

**Deliverables**
- First Dipole canvas animation
- First tutorial challenge (“Step through a function prologue”)
- Tag: `mvp0.2`

## 🌾 Milestone 2 — MVP 0.3 (Dipole UI Shell)
**Target:** July 2026  
Dipole gains an identity of its own through a cohesive interface.

**Goals**
- Embedded Ghostty terminal (LLDB shell)
- Metal visualization pane: stack frames, memory view, register tables
- Split-view or tabbed architecture
- Challenge definition file format

**Deliverables**
- First challenge pack (5–10 foundational challenges)
- Themed UI
- Tag: `mvp0.3`

## 🌻 Milestone 3 — MVP 0.4 (Dipole Academy Foundations)
**Target:** October 2026  
Dipole becomes a dojo — a place to practice and understand systems programming.

**Goals**
- In-app challenge browser with guided explanations and hints
- Local progress tracking and bootcamp-ready mode for group learning
- Community documentation

**Deliverables**
- “Systems Programming Foundations I” (20–30 challenges)
- Soft launch of Dipole Academy
- Tag: `mvp0.4`

## 🌺 Milestone 4 — MVP 0.5 (dipole-dbg Begins)
**Target:** March 2027  
A long-term architectural milestone: Dipole starts moving beyond LLDB.

**Goals**
- Start implementing `dipole-dbg` backend
- Attach, read registers, read memory, single-step
- Unified abstraction for LLDB ↔ `dipole-dbg` switching
- High-level backend design document

**Deliverables**
- First working `dipole-dbg` stepping experiment
- Tag: `mvp0.5`

## 🌸 Milestone 5 — 1.0 Candidate (Fully Integrated Learning Debugger)
**Target:** December 2027  
Dipole becomes a polished macOS application.

**Goals**
- Full Ghostty integration
- Full Metal visualization suite: trace timelines, memory map overlays, call graph visualization, stack frame animations, performance overlays
- Dipole Academy Level I & II (60–80 challenges)
- Bootcamp-ready infrastructure, website, documentation, and tutorial path
- App Store packaging

**Deliverables**
- Tag: `v1.0-rc`
- Public preview with demo videos

## 🏆 Milestone 6 — Dipole 1.0 Release
**Target:** January 2028  
A debugger. A learning platform. A distributed community of understanding.

**Goals**
- Full stability and refinement with polished user experience
- First global Dipole Bootcamp
- Launch of the Dipole community

**Deliverables**
- Tag: `v1.0`
- Dipole 1.0 launch event

## 🔭 Beyond 1.0 — The Future
**Dipole 2.0 (Debugger Evolution)**
- Full `dipole-dbg` backend
- Kernel debugging experiments
- Remote debugging
- JIT stepping and IR visualization

**Dipole as a Platform**
- Plugin architecture for visualizers, challenge packs, teaching modules
- Community-authored learning paths
- Online shared traces (“Dipole Playgrounds”)

**Distributed Learning Movement**
- Anonymous bootcamps; challenge-of-the-month
- Mentorship circles
- “Ask an Engineer” live sessions
- A global culture centered around deep understanding and craftsmanship

## 🧭 Roadmap Philosophy
Dipole is guided by three principles:
1. Understanding over complexity
2. Pedagogy over features
3. Depth over speed

Dipole exists to help people learn how computers really work —
to build a community of thinkers, explorers, and disciplined practitioners.

It is a tool, a teacher, and a quiet movement.

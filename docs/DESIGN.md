# DESIGN

## Purpose of This Document
`DESIGN.md` explains how Dipole’s intent becomes Dipole’s structure. It connects: vision, mission, pedagogy, values, and architecture. Dipole grows through Experiment-Driven Design: learning, debugging, and building are inseparable.

---

# 1. Design Philosophy
Dipole’s design follows a few essential principles:
- **Clarity First**: readability over cleverness; explicitness over opacity.
- **Vertical Slices, Not Horizontal Layers**: build small, coherent features end-to-end.
- **Experiment-Driven Design**: discover reality through experiments, observation, and refinement.
- **Pedagogy Shapes Design**: every output must help build a mental model.
- **Stable Exterior, Evolving Interior**: keep user-facing interfaces clean while internals evolve.
- **Code as a Teaching Tool**: explicit flows, minimal indirection, clear naming, documented reasoning.

---

# 2. Major Design Goals
- **Modern Debugger Experience**: clean CLI today; richer TUI is future design intent.
- **Transparency of the Machine**: design intent to reveal real structures; v0.2 covers event-sourced truth + semantic projections.
- **Path Toward a Native Backend (`dipoledb`)**: future design intent; v0.2 uses LLDB for event ingress only.

---

# 3. Experiment-Driven Development Workflow
Experiments drive understanding:
1. Ask a question.
2. Build the smallest program to expose it.
3. Observe system behavior.
4. Document insights.
5. Extract reusable abstractions.
6. Integrate into a vertical slice.
7. Repeat.

Experiments are permanent artifacts that teach, justify architecture, and become tests/docs.

---

# 4. Backend Architecture Design (Future Intent)
Design intent: a backend abstraction that could host LLDB now and `dipoledb` later. In v0.2, only LLDB event ingress is used; no backend swap exists. `dipoledb` is a future native backend concept, developed via experiments; not implemented in v0.2.

---

# 5. Component-Level Design
## Present in v0.2
- `core/`: event model (category, event_id, timestamp, optional payload); DebugSession (append-only log); Controller/Driver boundary for raw observations; semantic projections and registry (e.g., `event.kind@1`, `breakpoint.list@1`, `register.snapshot@1`); semantic feed producing Frames; minimal UiAdapter enforcing ProjectionId/version and rendering payload bytes.
- UI: CLI-only commands for semantic list/show/eval/render. Consumers are read-only and operate on Frames. No tmux integration or TUI in v0.2.

## Future / Conceptual
- Platform integration layer (e.g., `osx/`) for Mach/AArch64 specifics.
- Rich UI/TUI, tmux layouts, web UI.
- `dipoledb` native backend.
- Additional debugger abstractions (symbols, frames, memory) beyond current v0.2 surface.

---

# 6. Design Constraints
- Simplicity
- Explicitness
- OS isolation (as design intent)
- UI stability
- Minimal dependencies
- Teachable code

---

# 7. Evolution Path (Future Roadmap)
Evolution phases (LLDB wrapper → hybrid → native backend → rich TUI/visualizations → perf/introspection → cross-arch) are design intent and not implemented in v0.2.

---

## Closing Note
Dipole is designed the same way systems are understood: through curiosity, experimentation, and disciplined debugging. This is Experiment-Driven Design. This is Dipole.

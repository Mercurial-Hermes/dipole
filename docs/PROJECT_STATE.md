# Dipole — Project State (Authoritative Snapshot)

_Last updated: <fill in date>_

This file provides the **single source of truth** for Dipole’s current architecture, capabilities, and roadmap.  
Use it to quickly sync ChatGPT or any collaborator into the project.

---

## 1. Vision Summary

Dipole is a **deeply pedagogical debugger and performance exploration tool** focused on:

- Clear, intuitive stepping and tracing
- Illuminating low-level execution for systems programmers (Zig, C, Rust)
- Apple Silicon first, but not Apple Silicon only
- Designed with clarity, minimalism, and educational value at the core

Dipole is **not** a replacement for LLDB — it is a *human-friendly layer* over LLDB and, eventually, a full debugger of its own.

---

## 2. Current Architecture Overview

### Components

- **CLI entrypoints** in `exp/` (experimental prototypes)
- **LLDBDriver**
  - Wraps LLDB when spawned as a child
  - Currently supports:
    - attach
    - detach
    - stepi
    - read pc
  - Two modes explored:
    - **Batch mode** (working)
    - **Interactive PTY mode** (in-progress; Apple Silicon quirks)

- **Trace System**
  - `TraceSnapshot`
  - `TraceStep`
  - `pcDeltaBytes()`

---

## 3. Recent Experiments and Milestones

| Experiment | Status | Summary |
|-----------|--------|---------|
| exp0.1 | ✓ | Process listing |
| exp0.2 | ✓ | Attach + inspect |
| exp0.3 | ✓ | Stack frames |
| exp0.4 | ✓ | Single-step trace (before/after PC) |
| exp0.5 | in progress | Multi-step trace; batch LLDB; next goal: PTY-backed LLDBDriver |

---

## 4. Known Challenges

- LLDB suppresses its prompt when not connected to a TTY → interactive mode blocks
- Need to introduce PTY handling (`posix_openpt`, `grantpt`, `unlockpt`)
- Polling logic must avoid deadlock on Apple Silicon
- `LLDBDriver` interface needs to become stable, composable, and testable

---

## 5. Next Priorities

1. **Transition exp0.5 from batch to interactive PTY mode**
2. Introduce proper async-safe output reading
3. Create a stable public API for LLDBDriver
4. Build “Dipole Session” concept (records commands, steps, timeline)
5. First minimal CLI for MVP 0.1:
   - `dipole attach <pid>`
   - `dipole step`
   - `dipole trace --n <N>`
6. Update dev-log after each experiment

---

## 6. Long-Term Roadmap (High Level)

- Introduce a lightweight UI (terminal-first, optional browser mode)
- Real-time performance sampling overlays
- BPF-style insights (as allowed on macOS)
- Integrate with dipoledb for structural recording of execution traces
- Cross-platform backend architecture abstraction

---

## 7. How to Use This File

- Update sections 2–5 whenever architecture changes
- Keep terse but complete
- Paste section 1–5 into ChatGPT to instantly rehydrate context

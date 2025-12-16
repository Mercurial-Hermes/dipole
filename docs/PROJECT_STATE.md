# Dipole — Project State (Authoritative Snapshot)

**Current released version: v0.1.0 (MVP)**

*Last updated: 2025-12-16 — reflects v0.1.0 release state*

This file provides the **single source of truth** for Dipole’s current architecture, capabilities, and roadmap.  
Use it to quickly sync ChatGPT or any collaborator into the project.

---

## 1. Vision Summary

Dipole is a **pedagogical debugger**, a tool that reveals the internal workings of program execution with clarity and respect for the learner.

Key elements of the vision:
  - **Understanding-first**, not tool-first
  - A debugger that teaches
  - Modern, minimal, elegantly structured
  - Apple Silicon as the initial “flagship architecture”
  - Tight integration with LLDB initially, later a standalone debugger
 
Dipole aims to serve:
  - junior systems programmers
  - university students
  - Zig / C / Rust developers
  - anyone who wants to understand the machine, not just use it

Dipole is not designed to replace LLDB.
It is designed to **sit above LLDB** and eventually beside or beyond it, providing a conceptual on-ramp and ergonomic power tools.

---

## 2. Current Architecture Overview (v0.1.0)

Dipole is transitioning from experiment-driven prototyping into a modular architecture under `lib/`.

**Core Modules**

**PTY Subsystem** — `pty.zig`

Responsible for:
  - Allocating master/slave PTY
  - Setting CLOEXEC and non-blocking modes
  - Providing a safe close() helper
  - Correct behaviour on macOS (Darwin PTY semantics)

PTY is now the _foundation_ of interactive debugging, replacing pipe-based experiments.

**LLDBDriver** — `LLDBDriver.zig`

This is the beating heart of Dipole MVP 0.1.

Capabilities (as of Exp 0.7):
  - Spawn LLDB in interactive mode via PTY
  - Track LLDB's PID
  - Attach to a target PID
  - Launch a binary under LLDB
  - Send commands (`sendLine`)
  - Read output deterministically (`readUntilPrompt`)
  - Detect LLDB prompt reliably
  - Shutdown cleanly
  - Deallocate resources (`deinit`)
  - Check process health (`isAlive`)

This subsystem is **fully test-driven** (11 tests), ensuring stability across Zig or OS changes.

LLDBDriver is now stable enough to be used by:
  - the REPL
  - the future Dipole CLI
  - future pedagogical modules

**Trace System**

A simple but foundational model used in earlier experiments:
  - `TraceSnapshot { pc, timestamp_ns }`
  - `TraceStep { before, after }`
  - `pcDeltaBytes()`

This system will integrate with LLDBDriver for richer stepping introspection.

**Dipole REPL (Experiment 0.7)**

A working REPL now exists with:
  - startup banner
  - attach command
  - passthrough LLDB commands
  - stepping
  - register introspection
  - error handling
  - prompt-based LLDB IO

This is the **first interactive face** of Dipole.

---

## 3. Recent Experiments and Milestones

| Experiment | Status | Summary |
|-----------|--------|---------|
| exp0.1 | ✓ | Process listing |
| exp0.2 | ✓ | Attach + inspect |
| exp0.3 | ✓ | Stack frames |
| exp0.4 | ✓ | Single-step trace (before/after PC) |
| exp0.5 | ✓ | Multi-step trace (batch) |
| exp0.6 | ✓ | PTY-backed LLDB spawning & interactive IO |  
| exp0.7 | ✓ | Fully implemented LLDBDriver + REPL |

---

## 4. Known Challenges

**LLDB Prompt Behaviour**

LLDB suppresses its REPL prompt unless connected to a TTY.
**PTY usage is required** for correct interactive behaviour.

**macOS Non-blocking IO**

Darwin PTYs require:
  - non-blocking reads
  - timeout loops
  - careful prompt detection

**Potential LLDB Quirks**

  - prompt sometimes lags without flush
  - certain commands emit multi-phase outputs
  - signal handling differs between attach and launch flows

**Next Layer Complexity**

LLDBDriver is foundational, but the CLI and TUI layers will need to:
  - parse LLDB output more intelligently
  - build Dipole-native views (register view, PC delta, disassembly pane)
  - handle stepping visuals and educational messages

---

## 5. Next Priorities (Authoritatively Ordered)

1. **Integrate LLDBDriver into the main Dipole CLI**

  - unify REPL code into cmd/dipole
  - support: `dipole repl`, `dipole attach <pid>`, `dipole help`
  - robust error messages

2. **Surfaces core LLDB functionality in a Dipole style**

The REPL must offer value:

  - pretty register read
  - PC delta detection
  - simplified disassembly view
  - minimal but elegant formatting

3. **Architecture Cleanup After Exp 0.7**
Move modules from experiment folder into lib/core (done).

4. **Begin Dipole Session abstraction**

A Session will eventually store:
  - commands
  - outputs
  - timestamps
  - stepping history
  - trace snapshots

5. **MVP 0.1 Deliverable**

- Dipole CLI with REPL
- Attach/launch/step/read registers
- Basic pedagogical overlays
- Works best in Ghostty
- Clear documentation

6. **Maintain dev-log**
Every experiment → concise, polished write-up in docs/dev-log/.

7. **Longer-Term Roadmap**

- Browser or Ghostty-enhanced UI layer
- Visual execution traces
- Instruction timeline view
- Integration with dipole-dbg
- Native arm64 stepping backend
- Breaking free of LLDB

---

6. **Long-Term Vision (High-Level Roadmap)**

Dipole matures in three acts:

**Act I — LLDB Frontend (Current Phase)**
- teach fundamentals
- wrap LLDB safely
- build the REPL + educational UX
- explore PTY, signals, registers, stepping

**Act II — Dipole as a Debugging Engine**
- Mach-O loader
- DWARF reader
- ptrace-based stepping
- Dipole-driven breakpoints and tracepoints
- performance overlays

**Act III — Dipole as a Platform**
- advanced TUI + graphical UI
- Ghostty embedding
- pedagogy-first debugger experience
- cross-platform portability
- Dipole as a "workbench" for learning systems programming

---

## 7 Note on Future Versions

This document intentionally describes the **v0.1.0** state of Dipole.

Work toward **v0.2.0** introduces:
- expanded debugger workflows
- improved screen real estate via tmux
- architectural changes (e.g. brokered control of LLDB)

These changes are tracked separately in `ARCHITECTURE.md`, `ROADMAP.md`,
and upcoming dev-log entries, and are not reflected here until released.

---

## 8. How to Use This File

- Update sections 2–5 whenever architecture changes
- Keep terse but complete
- Paste section 1–5 into ChatGPT to instantly rehydrate context

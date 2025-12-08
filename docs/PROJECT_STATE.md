# Dipole — Project State (Authoritative Snapshot)

*Last updated: 2025-12-08*

This file provides the **single source of truth** for Dipole’s current architecture, capabilities, and roadmap.  
Use it to quickly sync ChatGPT or any collaborator into the project.

---

## 1. Vision Summary

Dipole is a **deeply pedagogical debugger and performance exploration tool** focused on:

- Clear, intuitive stepping and tracing
- Illuminating low-level execution for systems programmers (Zig, C, Rust)
- Apple Silicon first, but not Apple Silicon only
- Designed with clarity, minimalism, and educational value at the core

Dipole is **not** a replacement for LLDB.
It is a *human-friendly layer* over LLDB and, eventually, a full debugger of its own.

---

## 2. Current Architecture Overview

### Modules & Responsibilities

- **CLI entrypoints**
  Located in `exp/`, each experiment is a prototype to test an idea and generate insight.
- **LLDBDriver**
  A growing subsystem that:
    - Spawns and controls LLDB as a child process
  - Currently supports:
    - attach
    - detach
    - register read pc
    - stepi
  - Has two operating modes:
    - **Batch mode** (fully working): run LLDB commands, capture output once, exit
    - **Interactive mode (target state):**
      - **Backed by a pseudo-terminal (PTY)**
      - Allows LLDB to emit its normal prompt and behave interactively
      - Needed for incremental stepping, sustained sessions, REPL-like operation

- **Trace System**
Used for experiment-driven understanding of execution flow:
  - `TraceSnapshot { pc, timestamp_ns }`
  - `TraceStep { before, after }`
  - `pcDeltaBytes()`

---

## 3. Recent Experiments and Milestones

| Experiment | Status | Summary |
|-----------|--------|---------|
| exp0.1 | ✓ | Process listing |
| exp0.2 | ✓ | Attach + inspect |
| exp0.3 | ✓ | Stack frames |
| exp0.4 | ✓ | Single-step trace (before/after PC) |
| exp0.5 | ✓ | Multi-step trace (batch) |
| exp0.6 | in prog | Multi-step trace; batch LLDB; next goal: PTY-backed LLDBDriver |

---

## 4. Known Challenges

**LLDB prompt suppression**
LLDB **disables its REPL prompt** unless connected to a TTY.
This makes true interactive control impossible with plain pipes.

**Need for PTY**
Correct approach:
- `call posix_openpt()`
- `grantpt()`
- `unlockpt()`
- `ptsname()`
- give LLDB the **slave PTY** as its stdin/stdout/stderr

**Deadlock hazards**
On macOS/Apple Silicon:
- Pipe-based blocking reads can deadlock
- PTY requires **non-blocking I/O + poll/kevent/select** strategy

**LLDBDriver API still unstable**
We need:
  - clear command submission
  - defined lifetime model
  - robust read loop
  - error handling
  - “expect prompt” logic

---

## 5. Next Priorities (Authoritatively Ordered)

1.  **Complete PTY-backed LLDBDriver (exp0.6)**
    Goals:
    - Spawn LLDB connected to a PTY
    - Read from PTY without blocking
    - Detect the LLDB prompt reliably
    - Execute a simple REPL loop:
        - launch LLDB
        - wait for prompt
        - send `help`
        - read response
        - exit

2.  **Introduce async-safe, incremental output reading**
    - Switch from blocking `.reader().readAll()` to:
      - non-blocking fd
      - poll loop
      - accumulate buffer until prompt detected

3.  **Define a stable LLDBDriver interface**
    Rough future API:
    ```zig
    const LLDBDriver = struct {
        pub fn spawn() !LLDBDriver;
        pub fn send(self: *LLDBDriver, cmd: []const u8) !void;
        pub fn readUntilPrompt(self: *LLDBDriver, allocator: Allocator) ![]u8;
        pub fn step(self: *LLDBDriver) !TraceStep;
    };
    ```
    
4.  **Introduce Session abstraction**
    A <span style="background-color: grey;">“Dipole Session”.</span> will:
    - record commands
    - record outputs
    - timestamp everything
    - feed data into dipoledb eventually

5.  **MVP 0.1 Minimal CLI**
   - `dipole attach <pid>`
   - `dipole step`
   - `dipole trace --n <N>`
   
6.  **Maintain dev-log**
    Every experiment → cleaned write-up in `docs/dev-log/`
    
7.  **Long-Term Roadmap (High Level)**
    - Introduce a lightweight UI (terminal-first, optional browser mode)
    - Real-time performance sampling overlays
    - BPF-style insights (as allowed on macOS)
    - Integrate with dipoledb for structural recording of execution traces
    - Cross-platform backend architecture abstraction
    - Native Apple Silicon debugging engine (Mach-o parser + DWARF + ptrace/suspend/arm64 stepping)

---

## 8. How to Use This File

- Update sections 2–5 whenever architecture changes
- Keep terse but complete
- Paste section 1–5 into ChatGPT to instantly rehydrate context

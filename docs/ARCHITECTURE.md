# ARCHITECTURE

## Overview

Dipole’s architecture is intentionally **simple, modular, and extensible**.  
It serves two parallel goals:

- **practical debugging**, and  
- **pedagogical clarity**.

We defer complexity until truly needed and document architectural decisions as they emerge.  
Dipole’s structure should always be something a learner can read and understand.

---

# Runtime Architecture (v0.2)

As of v0.2, Dipole introduces a **brokered runtime topology** to support
multi-pane tmux layouts and richer pedagogical views, while continuing
to wrap LLDB as the underlying debugger engine.

## High-level Topology

- A single **Dipole Controller (Broker)** process owns:
  - the LLDB PTY session
  - all communication with LLDB
  - the authoritative debugging session state

- One or more **Dipole Clients** run in tmux panes:
  - a REPL client (interactive command input)
  - viewer clients (registers, disassembly, memory, “where am I”)

- Clients communicate with the controller via **local IPC**
  (Unix domain sockets or equivalent).

LLDB itself is never accessed directly by clients.

## Ownership and Invariants

The following invariants are non-negotiable:

1. **Single LLDB Owner**  
   Exactly one process communicates with LLDB via a single PTY.

2. **Serialized Command Execution**  
   All LLDB commands are executed sequentially by the controller.

3. **Derived Views Only**  
   UI clients never parse raw LLDB output; they consume structured or
   curated results produced by the controller.

4. **Stop-driven Updates**  
   On every stop event (breakpoint, step, signal), the controller refreshes
   core pedagogical views (e.g. registers, PC context, disassembly).

5. **Explicit Failure States**  
   If LLDB exits or detaches, the session transitions to an explicit
   `Exited` state and UI clients reflect this immediately.

These constraints preserve determinism, clarity, and teachability.

## Relationship to LLDB

In v0.2, Dipole remains a **thin wrapper over LLDB**:

- LLDB is treated as an external, authoritative debugger engine.
- Dipole orchestrates LLDB via its command-line interface.
- Escape hatches for raw LLDB commands are preserved.

This design allows Dipole to add pedagogical structure and ergonomic
screen real estate without obscuring the underlying debugger model.

Future versions may replace or augment this layer with `dipoledb`.

---

# Core Components

## 1. `core/` — Platform-Independent Debugger Logic

This layer defines Dipole’s fundamental abstractions:

- symbol and function representations  
- stack and frame models  
- register descriptions  
- error types  
- formatting and presentation helpers  

`core/` must remain clean, disciplined, and portable.  
It holds the conceptual model of “what debugging *is*,” independent of platform.

---

## 2. `osx/` — macOS + Apple Silicon Integration

This layer implements system-specific mechanisms for Apple Silicon and Mach:

- process enumeration (libproc, syscalls)  
- Mach task and thread ports  
- reading and writing registers  
- single-step execution  
- AArch64 thread state integration  

`osx/` isolates macOS complexity so the rest of Dipole remains understandable, testable, and open to future platform extensions.

---

## 3. `ui/` — CLI and Future TUI

The user interface expresses Dipole’s pedagogical mission.

**Initial focus:**

- clean command-line output  
- readable, structured explanations  
- raw views paired with interpreted views  

**tmux integration:**

In the near term, tmux-based multi-pane layouts are treated as a
first-class user interface. Screen real estate is a core pedagogical
tool: different panes provide focused, simultaneous views of program
state (e.g. registers, disassembly, memory, control flow).

The CLI and tmux UI are designed to evolve together.


**Later phases:**

- a rich TUI showing registers, stack frames, disassembly, and syscalls  
- instructional overlays that explain what the user is seeing  
- optional self-hosted web UI for visualizations and educational modules  

The UI is where Dipole’s clarity and teaching philosophy become tangible.

---

## 4. `dipoledb/` — Future Native Debugger Backend

`dipoledb` is Dipole’s long-term internal debugger engine — a native, Apple-Silicon-focused backend designed to eventually serve as a **drop-in replacement for LLDB**.

Its mission is ambitious but clear:

- provide native Mach + AArch64 debugging  
- expose registers, memory, and threads with zero abstraction opacity  
- deliver stepping, breakpoints, and inspection optimized for Apple Silicon  
- serve as a deeply understandable, fully documented backend  

Dipole will **initially wrap LLDB thinly**.  
This may remain the default path for a long time, ensuring stability and practicality.

Meanwhile, `dipoledb` will be developed **in parallel**, in the open, through:

- small, focused experiments,  
- incremental feasibility studies,  
- detailed dev diary entries,  
- visible architectural evolution.

As portions of `dipoledb` mature, experimental builds of Dipole may wrap the new backend to validate behavior, performance, and developer experience.

`dipoledb` is not merely a data store; it is the **future heart** of Dipole —  
a native debugger backend built with clarity, precision, and pedagogy.

---

## 5. `experiments/` — The Iterative Development Path

Dipole grows through **small, focused experiments**, not monolithic leaps.

Example trajectory:

- exp0.1 — process list  
- exp0.2 — attach + minimal inspection  
- exp0.3 — single-step behavior  
- exp0.4 — first trace capture  

Each experiment is:

- small  
- self-contained  
- documented  
- a learning artifact  

Experiments graduate into the main architecture or are retired with lessons preserved.

They form Dipole’s *pedagogical spine* at the code level.

---

# Long-Term Architectural Principles

- **Explicit over implicit** — clarity creates understanding.  
- **Readable over clever** — future learners matter.  
- **Isolation of OS-specific logic** — portability of thought, even if not yet of code.  
- **Minimal dependencies** — reduce cognitive overhead.  
- **Strong mental models** — architecture teaches by example.  
- **Pedagogical alignment** — debugging is learning.

Dipole should be a debugger you can understand by reading the code.

---

# Future Extensions

Dipole is built to grow without losing coherence.

Planned directions include:

- rich TUI instrumentation  
- browser-based visualization server  
- sampling + CPU-path insight for Apple Silicon  
- selective support for other architectures (e.g., x86_64)  
- deeper integration with Zig, C, and research-oriented tooling  

Dipole’s architecture is an evolving structure, shaped by experimentation, clarity, and purpose.

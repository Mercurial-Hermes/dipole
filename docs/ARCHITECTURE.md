# ARCHITECTURE

## Overview

Dipole’s architecture is intentionally **simple, modular, and extensible**.  
It serves two parallel goals:

- **practical debugging**, and  
- **pedagogical clarity**.

We defer complexity until truly needed and document architectural decisions as they emerge.  
Dipole’s structure should always be something a learner can read and understand.

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

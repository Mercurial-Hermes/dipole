      ◉───────◉
     (+)     (−)

# Dipole
### A Debugger and Pedagogical Exploration Tool for Apple Silicon

Dipole is a modern debugging and performance-exploration tool for developers targeting **Apple Silicon (AArch64)**.  
It aims to provide a clean, intuitive CLI/TUI experience while also serving as a **pedagogical instrument** that reveals how programs interact with the underlying machine.

Dipole begins life as a thin, ergonomic wrapper around **LLDB**, but its long-term trajectory is more ambitious:  
a native backend (`dipoledb`) built directly on **Mach**, **DWARF**, and **AArch64** — a debugger that helps developers *see* what is happening inside their programs and inside the system itself.

---

## ⚡ Goals

- Deliver a clear, ergonomic debugging experience for Zig and C developers on macOS.  
- Provide rich, structured views of stack frames, registers, processes, and program state.  
- Offer lightweight performance insight: sampling, CPU behaviour, execution flow.  
- Teach developers the fundamentals of Apple Silicon: Mach APIs, paging, registers, calling conventions, and memory layout.  
- Evolve toward a fully native backend that can optionally replace LLDB under Dipole.

---

## 🧠 Guiding Principles

- **Clarity over complexity** — debugging should reduce cognitive load.  
- **Architecture-aware** — Apple Silicon deserves first-class native tooling.  
- **Pedagogical by design** — every Dipole feature should help users understand how computers *actually work*.  
- **Vertical slices** — features evolve in small, coherent increments, each with clear purpose.  
- **Stable user interface** — the CLI/TUI remains consistent even as backend capabilities deepen.

---

## 🗺️ Roadmap (High-Level)

### **0.0.x — Foundation & Experiments**
- Establish repository, structure, build system, and documentation.  
- Produce focused experimental programs (`exp/`) exploring macOS process inspection, LLDB integration, and AArch64 concepts.  
- Build a library of small target programs (`targets/`) used for debugging experiments.  
- Create the initial Dipole CLI with basic commands:  
  - `dipole ps` — list processes  
  - `dipole attach <pid>` — wrap `lldb` behind a clean interface  

### **0.1.x — First Real Features**
- Stack frame and register displays (via LLDB).  
- Clean abstractions for process and thread state.  
- Begin shaping the pedagogical TUI.

### **0.2.x — Mach + AArch64 Backend Prototype**
- Explore reading registers natively.  
- Investigate Mach task ports, memory regions, and thread enumeration.

### **0.3.x — Native Stepping & Breakpoints (Prototype)**
- Wire up Mach APIs for control flow.  
- Begin lightweight DWARF mapping for function and line information.

### **0.5.x — dipoledb Emerges**
- Unified trace/event/snapshot store.  
- Begin using Dipole’s backend for common debugging flows.

### **1.0.0 — A Modern Debugging Experience**
- Rich TUI  
- Performance visualisation  
- Optional web UI served from the TUI client  

---

## 🌱 Current Status

Dipole is in its **experimental / architectural phase**.

The repository intentionally includes:

- **`exp/`** — small, focused experiments exploring process handling, attach mechanics, Mach APIs, and future backend ideas.  
- **`targets/`** — small C and Zig binar

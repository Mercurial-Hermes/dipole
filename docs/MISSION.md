# MISSION

## What Dipole Will Deliver

Dipole aims to provide a **modern, ergonomic debugger and performance exploration tool** for developers working on **Apple Silicon**, built with **Zig** and guided by clarity, simplicity, and pedagogical purpose.

Dipole operates at the intersection of debugging, performance, and learning.  
Its mission is threefold:

---

## 1. Build a Practical, High-Quality Debugger

Dipole will deliver a clean, reliable, architecture-aware debugging experience:

- Clear CLI and TUI ergonomics  
- Robust process inspection  
- Register, memory, symbol, and stack visibility  
- Reliable stepping, breakpoints, and execution flow  
- Optional performance overlays and CPU introspection  

The tool should feel stable, predictable, and trustworthy — a debugger that respects the user's time and attention.

---

## 2. Teach People How Systems Work

Dipole is a pedagogical instrument as much as a debugging tool.  
It will make internal mechanisms visible, structured, and understandable:

- Stack frames  
- Mach syscalls  
- AArch64 instructions  
- Memory layout  
- Process state transitions  
- Thread scheduling  

Dipole does not merely display data; it *explains structure*.  
Every feature is an opportunity to illuminate a concept and build intuition.

---

## 3. Demonstrate Human + Machine Collaboration

Dipole is built:

- with disciplined human reasoning,  
- supported by LLM-augmented exploration,  
- through an approach that models responsible, rigorous collaboration.

The project itself becomes a case study in how human insight and machine assistance can produce disciplined, comprehensible systems software.

---

# MVP 0.1 Goals

Dipole’s first milestone will include:

- Process enumeration on macOS  
- Attach to a target PID  
- Read minimal state (threads, registers, or a memory snippet)  
- Clean, instructive CLI output  
- A small internal “dipoledb” store for traces/snapshots  
- A Zig codebase with professional structure and tests  

MVP 0.1 is intentionally small.  
It is the first foothold on a long climb.

---

# Long-Term Mission

Dipole will grow into:

- A full debugger backend (`dipoledb`)  
- A rich TUI with instructional overlays  
- Optional browser-based visualizations  
- Sampling and performance analysis for Apple Silicon  
- Integration with Zig, C, and research-oriented tooling  
- An educational platform for understanding systems programming  

Dipole is a practical tool with a pedagogical soul.  
This dual mission defines the project and guides every decision.

---

Dipole exists to empower understanding — for those who debug, those who learn, and those who build the next generation of systems.

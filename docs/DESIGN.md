# DESIGN

## Purpose of This Document

`DESIGN.md` explains **how Dipole’s intent becomes Dipole’s structure**.

It connects:

- Vision — why Dipole exists  
- Mission — what Dipole will deliver  
- Pedagogy — how Dipole teaches  
- Values — how Dipole behaves  
- Architecture — how Dipole is built  

But above all, Dipole’s design is shaped by **Experiment-Driven Design**:  
a method where learning, debugging, and building are inseparable.

Dipole grows through understanding — just as debugging itself does.

---

# 1. Design Philosophy

Dipole’s design follows a few essential principles:

### **1.1 Clarity First**
Dipole favors readability over cleverness, explicitness over opacity, explanation over silence.  
The debugger should reflect its purpose: to make complex systems *understandable*.

### **1.2 Vertical Slices, Not Horizontal Layers**
Dipole grows by building small, coherent features end-to-end:

- a CLI command  
- a backend call  
- an OS interaction  
- a pedagogical output  

This “vertical slice” approach produces clarity, momentum, and insight.

### **1.3 Experiment-Driven Design**
Dipole is built the way systems are understood:  
**by experimenting, observing behavior, debugging, and refining.**

Traditional TDD tries to lock behavior down in advance.  
Dipole’s domain — Mach, LLDB, AArch64, Zig, registers, memory — *must be discovered*, not merely specified.

Experiment-Driven Design means:

- start with a question  
- write the smallest Zig/C program that exposes the concept  
- observe real system behavior  
- document insights in the dev diary  
- extract reusable abstractions  
- promote concepts into architecture  
- repeat  

Dipole is a debugger built *through* debugging.

### **1.4 Pedagogy Shapes Design**
Every output, structure, and abstraction must answer:

> “Does this help the user build a mental model of the system?”

If not, redesign it.

### **1.5 Stable Exterior, Evolving Interior**
Dipole’s CLI/TUI must remain clean and predictable, even as the backend evolves from:

LLDB → hybrid → partial `dipoledb` → native `dipoledb`

This preserves user trust and understanding.

### **1.6 Code as a Teaching Tool**
Dipole’s design insists that the codebase itself should be easy to learn from:

- explicit flows  
- minimal indirection  
- clear naming  
- documented reasoning  
- experiments preserved historically  

The implementation must never obscure the truth it aims to teach.

---

# 2. Major Design Goals

Dipole’s design supports three primary goals:

### **2.1 A Modern Debugger Experience**
- clean CLI  
- future rich TUI  
- architecture-aware displays  
- readable stack/register/memory layouts  

### **2.2 Transparency of the Machine**
Dipole must reveal the real structure of:

- Mach  
- AArch64  
- stack frames  
- instructions  
- memory layout  
- process and thread transitions  

Every design choice prioritizes understanding over abstraction.

### **2.3 A Path Toward a Native Backend (`dipoledb`)**
Dipole’s backend must be arranged so that:

- LLDB works now  
- experiments feed native development  
- `dipoledb` grows incrementally  
- backends can be swapped experimentally  

Design cannot assume LLDB is permanent, nor that `dipoledb` is immediate.

---

# 3. Experiment-Driven Development Workflow

Dipole uses **experiments** not only for prototyping — but as the fundamental mechanism of understanding.

### **3.1 The Experiment Loop**

1. **Ask a Question**  
   What system behavior do we want to understand?  
   What debugger feature depends on that understanding?

2. **Construct the Smallest Program**  
   A tiny C/Zig binary that isolates the phenomenon.

3. **Observe System Behavior**  
   Run the experiment. Attach to it. Step through it. Break it.  
   Let the machine teach us.

4. **Write Down Insights**  
   Each experiment produces a documented lesson in the dev diary.

5. **Extract and Generalize**  
   Turn insight into a reusable abstraction in `core/` or `osx/`.

6. **Integrate into Dipole Proper**  
   Build a vertical slice so users can experience that insight.

7. **Repeat**  
   Debugging is learning. Dipole’s development mirrors this.

### **3.2 Why Experiments, Not TDD?**

TDD assumes:

- behavior is known in advance,  
- interfaces are stable,  
- environment is deterministic.  

Dipole’s domain violates all three.

Experiment-Driven Design respects reality:

- systems programming requires discovering what’s true,  
- OS and CPU behavior must be learned empirically,  
- debugging is inherently exploratory.  

Dipole’s architecture grows from knowledge obtained *through* experiments, not from predetermined assumptions.

### **3.3 Experiments As Permanent Artifacts**
Experiments are not disposable:

- they teach future contributors  
- they record historical insights  
- they justify architectural decisions  
- they become tests, examples, and documentation  
- they reflect Dipole’s values  

`experiments/` is a living laboratory.

---

# 4. Backend Architecture Design

Dipole uses a **backend abstraction layer**:

        +----------------------+
        |      UI (CLI/TUI)    |
        +-----------+----------+
                    |
                    v
        +----------------------+
        |   Backend Interface  |
        |   (portable layer)   |
        +-----------+----------+
                    |
      +-------------+------------------+
      |                                |
      v                                v
 +------------+               +----------------+
 |    LLDB    |               |    dipoledb    |
 | thin layer |               | native backend |
 +------------+               +----------------+


### **4.1 Backend Responsibilities**
Provide:

- process enumeration  
- attach/detach  
- register access  
- memory read/write  
- stepping & breakpoints  
- symbol lookup  

### **4.2 LLDB as Initial Backend**
Chosen for practicality, breadth, and stability.

### **4.3 dipoledb as Future Backend**
Developed in parallel via experiments:

- incremental  
- transparent  
- Apple Silicon–optimized  
- carefully documented  

Experiment builds of Dipole may target `dipoledb` to validate feasibility.

---

# 5. Component-Level Design

## **5.1 `core/` — Conceptual Model Layer**
Defines portable debugger concepts:

- registers  
- symbols  
- frame models  
- memory abstractions  
- pretty-formatting  

## **5.2 `osx/` — Platform Integration**
Implements:

- Mach task/thread ops  
- libproc enumeration  
- register and memory primitives  
- single-step facilities  

## **5.3 `ui/` — Presentation Layer**
Embodies pedagogy:

- interprets data for humans  
- explains structure  
- shows raw + interpreted forms  
- maintains consistency and clarity  

## **5.4 `dipoledb/` — Future Native Backend**
For:

- native Mach/AArch64 debugging  
- traces, snapshots, histories  
- explicit and readable structures  
- step-by-step evolution visible in dev diary  

## **5.5 `experiments/` — Living Design Lab**
Where insight forms.

Experiments:

- drive architecture  
- inform abstractions  
- capture lessons  
- guide backend evolution  
- remain as teaching artifacts

Experiment-Driven Design is the heart of Dipole.

---

# 6. Design Constraints

Dipole must respect:

- **simplicity**  
- **explicitness**  
- **OS isolation**  
- **UI stability**  
- **minimal dependencies**  
- **teachable code**  

These constraints enforce Dipole’s pedagogical and architectural purpose.

---

# 7. Evolution Path

Dipole grows in phases:

1. LLDB wrapper (0.x)  
2. Hybrid backend (LLDB + experimental `dipoledb`)  
3. Partial native backend  
4. Full native backend for common tasks  
5. Pedagogical TUI + visualizations  
6. Apple Silicon performance + introspection  
7. Optionally: other architectures  

Throughout all phases:

**Experiment → Insight → Abstraction → Architecture**

---

## Closing Note

Dipole is designed the same way systems are understood:  
through curiosity, experimentation, and disciplined debugging.

It is a debugger built *by* debugging.  
A tool built *by* learning.  
A system built *by* understanding.

This is Experiment-Driven Design.  
This is Dipole.

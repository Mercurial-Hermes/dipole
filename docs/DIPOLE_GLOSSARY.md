# Dipole Glossary

A shared vocabulary for Dipole development.

---

## LLDBDriver
A Zig struct that wraps LLDB as a subprocess, providing:
- writeCommand
- readUntilPrompt / readPc
- attach / detach
- stepi

Two modes:
- **Batch mode** — reliable, no prompt, used in exp0.5
- **Interactive PTY mode** — ultimate target, requires pseudo-terminal

---

## TraceSnapshot
A record of the CPU state at a moment:
- pc
- timestamp_ns

---

## TraceStep
A before/after pair showing:
- pc delta
- time delta
- potential control flow insights

---

## Experiment Tag (expX.Y)
Marks completion of a pedagogical experiment:
- contains code
- dev-log entry
- insights gained

---

## Dipole Session (planned)
An abstraction that will:
- hold context
- manage driver state
- record traces
- allow replay/visualisation

---

## PTY (Pseudo-Terminal)
A fake terminal LLDB must be attached to in interactive mode to emit prompts.

Key functions:
- `posix_openpt`
- `grantpt`
- `unlockpt`

---

## “Batch LLDB”
LLDB mode using:
lldb --batch --one-line <cmd> --one-line <cmd>

Does not print prompts. Easier to drive but limited in interactivity.

---

## Dipoledb (future)
Structured database of debug/tracing events.

---

## MVP 0.1 (planned)
- Attach
- Step
- Multi-step trace
- Clean CLI ergonomics
- Early LLDBDriver API

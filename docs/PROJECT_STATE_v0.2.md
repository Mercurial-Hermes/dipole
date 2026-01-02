# Dipole — Project State (v0.2)

Current version: v0.2.0 (architecturally sealed)

## What Exists
- Event-sourced truth (TS1)
- Pure, deterministic semantic projections and registry (TS2)
- Semantic feed producing Frames (TS3)
- Minimal intent plane (`intent.ping` only) (TS4)
- CLI semantic commands: list/show/eval/render
- Read-only consumers (Frames only; no authority)
- Deterministic replay

## What Explicitly Does Not Exist
- tmux runtime
- IPC or brokered control
- Controller-driven UI refresh
- LLDB passthrough
- Register parsing/normalization in UI

## Current Focus
- Dojo course readiness on v0.2 invariants
- Pedagogical scripts using read-only semantic outputs
- Preserving sealed TS1–TS4 contracts

## References
- `ARCHITECTURE.md` — authoritative v0.2 system description
- `DESIGN.md` — philosophy and future intent

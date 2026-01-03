# Request Routing (Transport Envelope)

## Purpose

Define a minimal, transport-level envelope for command bytes so the Controller
can distinguish request sources without interpreting intent or payloads.

This is plumbing below the intent boundary.

---

## Non-Goals

- Do not introduce intent types or semantics
- Do not parse or interpret payload bytes
- Do not change DebugSession event categories or meaning
- Do not describe UI panes or tmux

---

## Envelope Shape

Binary framing on the command pipe:

- `source_id: u32` (little-endian, opaque)
- `len: u32` (little-endian, payload length)
- `payload: [len]u8` (raw command bytes)

`source_id` is routing metadata only. It must not encode meaning.

---

## Responsibilities

- CLI (session bootstrap) and the Dipole REPL write envelopes to the command pipe.
- Controller reads the envelope, forwards `payload` unchanged to the Driver.
- Driver interface is unchanged.
- DebugSession admission is unchanged; observations remain raw.

---

## Intent Boundary

Intent formation remains in the CLI / REPL.

The envelope exists **below** the intent boundary and must not be treated as
an intent representation.

---

## Compatibility

Single-source operation remains valid by using a constant `source_id`.

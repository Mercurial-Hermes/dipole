/// Driver.zig
///
/// See docs/architecture/dipole-minimal-type-graph.md
/// See docs/architecture/dipole-module-boundary.md
/// See docs/architecture/execution-source.md
/// See docs/architecture/interaction-flow.md
///
/// ───────────────────────────────────────────────────────────────────────────
/// Driver — Transport Ingest Boundary
/// ───────────────────────────────────────────────────────────────────────────
///
/// This module defines the **Driver boundary object**.
///
/// A Driver is *not* a debugger, client, or adapter.
/// It is the **narrowest possible membrane through which external reality
/// enters Dipole**.
///
/// The Driver’s sole responsibility is to:
///   - perform side effects against an external system (process, PTY, pipe)
///   - emit **raw transport observations** exactly as they are observed
///
/// A Driver must **not**:
///   - interpret bytes
///   - parse output
///   - detect prompts
///   - infer execution state
///   - buffer for semantic completeness
///   - attach meaning, intent, or structure
///
/// All observations produced by a Driver are admitted *verbatim* as Events
/// by the Controller. The Controller performs only a coarse, mechanical
/// categorisation; no semantic meaning is introduced at ingress.
///
/// This boundary is intentionally minimal to ensure:
///   - a single, enforceable ingest point
///   - kernel-owned ordering and replay determinism
///   - backend plugability (LLDB, dipole-dbg, hybrid, replay)
///
/// Semantic debugger logic (e.g. LLDB prompt handling, state machines,
/// thread lists, stop reasons) must live *above* this boundary and must
/// never be implemented here.
///
/// At this stage, this file defines only the interface, enabling Controller
/// development and testing (TS1-003, TS1-004) without committing to any
/// specific backend implementation.
///
/// If this file ever grows “smart”, the architecture has been violated.
/// ───────────────────────────────────────────────────────────────────────────
const std = @import("std");

/// A raw, transport-level observation emitted by a Driver.
///
/// Observations reflect *what was observed*, not what it means.
/// They are not guaranteed to be complete, atomic, ordered, or stable.
///
/// Multiple observations may correspond to a single logical command.
/// A single observation may contain partial or fragmented data.
pub const DriverObservation = union(enum) {
    /// Bytes written to the backend.
    tx: []const u8,

    /// Bytes read from the backend.
    rx: []const u8,

    /// A backend-emitted prompt marker, if the transport itself produces one.
    /// This carries no semantic meaning and must not be interpreted here.
    prompt,
};

/// Driver boundary interface.
///
/// The Driver is opaque to the Controller.
/// All state is owned by the concrete implementation behind `ctx`.
///
/// The Controller:
///   - calls `send` to perform a side effect
///   - repeatedly calls `poll` to admit observed reality
///
/// The Driver controls pacing; returning `null` from `poll` means
/// “no observations available *at this moment*”.
pub const Driver = struct {
    ctx: *anyopaque,

    /// Send raw bytes to the backend.
    ///
    /// This is a side effect.
    /// No observation is implied by this call alone.
    send: *const fn (ctx: *anyopaque, line: []const u8) anyerror!void,

    /// Poll for the next raw transport observation.
    ///
    /// Returns:
    ///   - `DriverObservation` when something was observed
    ///   - `null` when nothing is currently available
    ///
    /// This function must not block indefinitely and must not interpret data.
    poll: *const fn (ctx: *anyopaque) ?DriverObservation,
};

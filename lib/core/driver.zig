/// Driver.zig
///
/// See docs/architecture/dipole-minimal-type-graph.md
/// See docs/architecture/dipole-module-boundary.md
/// See docs/architecture/execution-source.md
/// See docs/architecture/interaction-flow.md
///
/// A Driver produces raw transport observations only.
/// It must not interpret, classify, or attach meaning to what it observes.
/// All observations are admitted as Events by the Controller without modification.
///
/// Just interface at this stage - to enable Controller development via TS1-003
///
const std = @import("std");

pub const DriverObservation = union(enum) {
    tx: []const u8,
    rx: []const u8,
    prompt,
};

pub const Driver = struct {
    ctx: *anyopaque,

    /// Send a raw command line to the backend.
    /// This is a side effect.
    send: *const fn (ctx: *anyopaque, line: []const u8) anyerror!void,

    /// Poll for the next raw observation, if any.
    /// Returns null when no observations are currently available.
    poll: *const fn (ctx: *anyopaque) ?DriverObservation,
};

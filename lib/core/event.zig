const std = @import("std");

pub const Category = enum {
    session,
    command,
    backend,
    execution,
    snapshot,
};

/// Event
///
/// See docs/architecture/event-model.md
///
/// Represents a single debugger event.
/// Thin and boring for now — will grow as tests demand.
pub const Event = struct {
    category: Category,
    seq: u64,
    timestamp: ?std.time.Instant = null,
};

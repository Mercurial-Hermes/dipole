//lib/core/event.zig

const std = @import("std");

pub const Category = enum {
    session,
    command,
    backend,
    execution,
    snapshot,
};

pub const SnapshotKind = enum {
    registers,
};

pub const SnapshotPayload = struct {
    snapshot_kind: SnapshotKind,
    source_id: u32,
    captured_at_event_seq: u64,
    payload: []const u8,
    payload_owned: bool = false,
};

/// Event
///
/// See docs/architecture/event-model.md
///
/// Represents a single debugger event.
/// Thin and boring for now — will grow as tests demand.
pub const Event = struct {
    category: Category,
    event_id: u64,
    timestamp: ?std.time.Instant = null,
    /// Optional opaque payload for snapshot-style events; empty by default.
    payload: []const u8 = &.{},
    /// Whether DebugSession owns payload memory.
    payload_owned: bool = false,
    /// Optional snapshot payload for snapshot events only.
    snapshot: ?SnapshotPayload = null,
};

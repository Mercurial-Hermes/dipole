/// Projection
///
/// See docs/architecture/derived_state.md
/// See docs/architecture/semantic-derivation.md
///
const std = @import("std");
const EventMod = @import("event");
const EventKindMod = @import("event_kind");
pub const Event = EventMod.Event;
pub const Category = EventMod.Category;
pub const EventKind = EventKindMod.EventKind;

pub const CategoryCount = struct {
    category: Category,
    count: usize,
};

pub const RegisterSnapshotStatus = enum {
    empty,
    present,
};

pub const RegisterSnapshotView = struct {
    status: RegisterSnapshotStatus,
    snapshot_event_id: ?u64,
    captured_at_event_seq: ?u64,
    payload_bytes: []const u8,
};

pub fn latestRegisterSnapshot(events: []const Event) RegisterSnapshotView {
    var last_event_id: ?u64 = null;
    var last_capture_seq: ?u64 = null;
    var last_payload: []const u8 = &.{};

    for (events) |e| {
        if (e.category != .snapshot) continue;
        const snap = e.snapshot orelse continue;
        if (snap.snapshot_kind != .registers) continue;
        last_event_id = e.event_id;
        last_capture_seq = snap.captured_at_event_seq;
        last_payload = snap.payload;
    }

    if (last_event_id == null) {
        return .{
            .status = .empty,
            .snapshot_event_id = null,
            .captured_at_event_seq = null,
            .payload_bytes = &.{},
        };
    }

    return .{
        .status = .present,
        .snapshot_event_id = last_event_id,
        .captured_at_event_seq = last_capture_seq,
        .payload_bytes = last_payload,
    };
}

pub fn projectEventKinds(
    alloc: std.mem.Allocator,
    events: []const Event,
) ![]EventKind {
    const event_kinds = try alloc.alloc(EventKind, events.len);
    errdefer alloc.free(event_kinds);

    for (events, 0..) |e, i| {
        event_kinds[i] = switch (e.category) {
            .session => .SessionLifecycle,
            .command => .UserAction,
            .backend, .execution => .EngineActivity,
            .snapshot => .Snapshot,
        };
    }
    return event_kinds; // caller frees
}

/// Returns the total number of events in the log.
///
/// This is a trivial projection used to establish the projection boundary.
/// Projections are pure, non-authoritative, and rebuildable.
pub fn eventCount(events: []const Event) usize {
    return events.len;
}

/// Returns a deterministic list of category counts, sorted by enum order.
/// Only categories with non-zero counts are returned.
pub fn categoryCounts(
    alloc: std.mem.Allocator,
    events: []const Event,
) ![]CategoryCount {
    const category_values = comptime blk: {
        const fields = std.meta.fields(Category);
        var tmp: [fields.len]Category = undefined;
        for (fields, 0..) |field, i| {
            tmp[i] = @enumFromInt(field.value);
        }
        break :blk tmp;
    };

    var counts = std.mem.zeroes([category_values.len]usize);
    for (events) |evnt| {
        const idx = @intFromEnum(evnt.category);
        counts[idx] += 1;
    }

    var list = std.ArrayList(CategoryCount).init(alloc);
    errdefer list.deinit();

    for (category_values, 0..) |cat, i| {
        const c = counts[i];
        if (c == 0) continue;
        try list.append(.{
            .category = cat,
            .count = c,
        });
    }

    return list.toOwnedSlice();
}

/// Returns a slice of categories in the order they appear in the event log.
///
pub fn categoryTimeline(alloc: std.mem.Allocator, events: []const Event) ![]Category {
    var timeline = std.ArrayList(Category).init(alloc);
    errdefer timeline.deinit();

    for (events) |ev| {
        try timeline.append(ev.category);
    }
    return timeline.toOwnedSlice();
}

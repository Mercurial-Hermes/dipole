const std = @import("std");
const ds = @import("debug_session");
const ev = @import("event");
const proj = @import("projection.zig");

fn expectCategoryCountsEqual(a: []const proj.CategoryCount, b: []const proj.CategoryCount) !void {
    try std.testing.expectEqual(a.len, b.len);
    for (a, b) |ea, eb| {
        try std.testing.expectEqual(ea.category, eb.category);
        try std.testing.expectEqual(ea.count, eb.count);
    }
}

fn appendSampleEvents(session: *ds.DebugSession) !void {
    try session.append(.session);
    try session.append(.backend);
    try session.append(.command);
    try session.append(.execution);
    try session.append(.command);
    try session.append(.execution);
    try session.append(.backend);
    try session.append(.snapshot);
    try session.append(.command);
}

test "projection.categoryCounts_is_replay_equivalent" {
    var dbs_a = ds.DebugSession.init(std.testing.allocator);
    defer dbs_a.deinit();

    try appendSampleEvents(&dbs_a);

    const events_original = dbs_a.eventsView();

    var dbs_b = try ds.DebugSession.initFromEvents(std.testing.allocator, events_original);
    defer dbs_b.deinit();

    const events_replayed = dbs_b.eventsView();

    const events_by_cat_a = try proj.categoryCounts(std.testing.allocator, events_original);
    defer std.testing.allocator.free(events_by_cat_a);
    const events_by_cat_b = try proj.categoryCounts(std.testing.allocator, events_replayed);
    defer std.testing.allocator.free(events_by_cat_b);

    try expectCategoryCountsEqual(events_by_cat_a, events_by_cat_b);
}

test "projection.categoryTimeline_is_replay_equivalent" {
    var dbs_a = ds.DebugSession.init(std.testing.allocator);
    defer dbs_a.deinit();

    try appendSampleEvents(&dbs_a);

    const events_original = dbs_a.eventsView();

    var dbs_b = try ds.DebugSession.initFromEvents(std.testing.allocator, events_original);
    defer dbs_b.deinit();

    const events_replayed = dbs_b.eventsView();

    const timeline_a = try proj.categoryTimeline(std.testing.allocator, events_original);
    defer std.testing.allocator.free(timeline_a);
    const timeline_b = try proj.categoryTimeline(std.testing.allocator, events_replayed);
    defer std.testing.allocator.free(timeline_b);

    try std.testing.expectEqual(timeline_a.len, timeline_b.len);

    for (timeline_a, timeline_b) |o, r| {
        try std.testing.expectEqual(o, r);
    }
}

test "TS2-001: projectEventKinds derives stable semantic classification" {
    var dbs_a = ds.DebugSession.init(std.testing.allocator);
    defer dbs_a.deinit();

    try appendSampleEvents(&dbs_a);

    const events_vw = dbs_a.eventsView();

    const expected_kinds = try std.testing.allocator.alloc(proj.EventKind, events_vw.len);
    defer std.testing.allocator.free(expected_kinds);

    for (events_vw, 0..) |e, i| {
        expected_kinds[i] = switch (e.category) {
            .session => .SessionLifecycle,
            .command => .UserAction,
            .backend, .execution => .EngineActivity,
            .snapshot => .Snapshot,
        };
    }

    const actual_event_kinds = try proj.projectEventKinds(std.testing.allocator, events_vw);
    defer std.testing.allocator.free(actual_event_kinds);

    try std.testing.expectEqual(events_vw.len, actual_event_kinds.len);

    for (expected_kinds, 0..) |ek, i| {
        try std.testing.expectEqual(ek, actual_event_kinds[i]);
    }
}

test "TS2-001: semantic projection preserves slice ordering (ignores event_id)" {
    // Intentional mismatch between slice order and event_id values to catch any reordering.
    const events = [_]ev.Event{
        .{ .category = .command, .event_id = 100, .timestamp = null },
        .{ .category = .session, .event_id = 10, .timestamp = null },
        .{ .category = .backend, .event_id = 50, .timestamp = null },
        .{ .category = .snapshot, .event_id = 200, .timestamp = null },
    };

    const kinds = try proj.projectEventKinds(std.testing.allocator, &events);
    defer std.testing.allocator.free(kinds);

    try std.testing.expectEqual(@as(usize, events.len), kinds.len);
    try std.testing.expectEqual(proj.EventKind.UserAction, kinds[0]);
    try std.testing.expectEqual(proj.EventKind.SessionLifecycle, kinds[1]);
    try std.testing.expectEqual(proj.EventKind.EngineActivity, kinds[2]);
    try std.testing.expectEqual(proj.EventKind.Snapshot, kinds[3]);
}

// Semantic meaning must not depend on allocation, construction path,
// or object identity — only on immutable event truth.
test "TS2-001: projectEventKinds is replay-deterministic" {
    var dbs_a = ds.DebugSession.init(std.testing.allocator);
    defer dbs_a.deinit();

    try appendSampleEvents(&dbs_a);
    const events_original = dbs_a.eventsView();

    var dbs_b = try ds.DebugSession.initFromEvents(std.testing.allocator, events_original);
    defer dbs_b.deinit();
    const events_replayed = dbs_b.eventsView();

    const kinds_a = try proj.projectEventKinds(std.testing.allocator, events_original);
    defer std.testing.allocator.free(kinds_a);
    const kinds_b = try proj.projectEventKinds(std.testing.allocator, events_replayed);
    defer std.testing.allocator.free(kinds_b);

    try std.testing.expectEqual(kinds_a.len, kinds_b.len);
    for (kinds_a, kinds_b) |ka, kb| {
        try std.testing.expectEqual(ka, kb);
    }
}

test "TS2-001: projectEventKinds ignores non-permitted fields (input field isolation)" {
    // Same categories/event_ids/order; differing timestamps.
    const base_events = [_]ev.Event{
        .{ .category = .session, .event_id = 1, .timestamp = null },
        .{ .category = .command, .event_id = 2, .timestamp = null },
        .{ .category = .backend, .event_id = 3, .timestamp = null },
        .{ .category = .execution, .event_id = 4, .timestamp = null },
    };

    var tweaked = base_events;
    tweaked[0].timestamp = std.mem.zeroes(std.time.Instant);
    tweaked[1].timestamp = std.mem.zeroes(std.time.Instant);
    tweaked[2].timestamp = std.mem.zeroes(std.time.Instant);
    tweaked[3].timestamp = std.mem.zeroes(std.time.Instant);

    const kinds_a = try proj.projectEventKinds(std.testing.allocator, &base_events);
    defer std.testing.allocator.free(kinds_a);
    const kinds_b = try proj.projectEventKinds(std.testing.allocator, &tweaked);
    defer std.testing.allocator.free(kinds_b);

    try std.testing.expectEqual(kinds_a.len, kinds_b.len);
    for (kinds_a, kinds_b) |ka, kb| {
        try std.testing.expectEqual(ka, kb);
    }
}

test "projection.latestRegisterSnapshot returns empty when no snapshots exist" {
    const events = [_]ev.Event{
        .{ .category = .session, .event_id = 0, .timestamp = null },
        .{ .category = .command, .event_id = 1, .timestamp = null },
    };

    const view = proj.latestRegisterSnapshot(&events);
    try std.testing.expectEqual(proj.RegisterSnapshotStatus.empty, view.status);
    try std.testing.expect(view.snapshot_event_id == null);
    try std.testing.expect(view.captured_at_event_seq == null);
    try std.testing.expectEqual(@as(usize, 0), view.payload_bytes.len);
}

test "projection.latestRegisterSnapshot selects latest register snapshot by order" {
    const snap_old = ev.SnapshotPayload{
        .snapshot_kind = .registers,
        .source_id = 1,
        .captured_at_event_seq = 5,
        .payload = "old",
    };
    const snap_new = ev.SnapshotPayload{
        .snapshot_kind = .registers,
        .source_id = 1,
        .captured_at_event_seq = 9,
        .payload = "new",
    };

    const events = [_]ev.Event{
        .{ .category = .snapshot, .event_id = 2, .timestamp = null, .snapshot = snap_old },
        .{ .category = .snapshot, .event_id = 3, .timestamp = null, .snapshot = snap_new },
    };

    const view = proj.latestRegisterSnapshot(&events);
    try std.testing.expectEqual(proj.RegisterSnapshotStatus.present, view.status);
    try std.testing.expectEqual(@as(?u64, 3), view.snapshot_event_id);
    try std.testing.expectEqual(@as(?u64, 9), view.captured_at_event_seq);
    try std.testing.expectEqualStrings("new", view.payload_bytes);
}

test "projection.latestRegisterSnapshot ignores snapshot events without payload" {
    const snap = ev.SnapshotPayload{
        .snapshot_kind = .registers,
        .source_id = 1,
        .captured_at_event_seq = 1,
        .payload = "regs",
    };
    const events = [_]ev.Event{
        .{ .category = .snapshot, .event_id = 1, .timestamp = null, .payload = "not-a-snapshot" },
        .{ .category = .snapshot, .event_id = 2, .timestamp = null, .snapshot = snap },
    };

    const view = proj.latestRegisterSnapshot(&events);
    try std.testing.expectEqual(proj.RegisterSnapshotStatus.present, view.status);
    try std.testing.expectEqual(@as(?u64, 2), view.snapshot_event_id);
    try std.testing.expectEqualStrings("regs", view.payload_bytes);
}

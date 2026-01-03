const std = @import("std");
const ds = @import("debug_session.zig");
const ev = @import("event");

test "debug_session.test.append_preserves_order_and_ids_are_monotonic" {
    var dbs = ds.DebugSession.init(std.testing.allocator);
    defer dbs.deinit();

    try dbs.append(.session);
    try dbs.append(.session);
    try dbs.append(.session);

    const events_view = dbs.eventsView();

    try std.testing.expectEqual(@as(usize, 3), events_view.len);

    try std.testing.expectEqual(@as(u64, 0), events_view[0].event_id);
    try std.testing.expectEqual(@as(u64, 1), events_view[1].event_id);
    try std.testing.expectEqual(@as(u64, 2), events_view[2].event_id);
}

test "debug_session.test.mutation_of_recorded_truth_not_possible" {
    var dbs = ds.DebugSession.init(std.testing.allocator);
    defer dbs.deinit();

    try dbs.append(.session);
    try dbs.append(.session);
    try dbs.append(.session);

    const events_view = dbs.eventsView();

    // Assert the public API is read-only
    const info = @typeInfo(@TypeOf(events_view));
    switch (info) {
        .pointer => |p| {
            try std.testing.expect(p.size == .slice);
            try std.testing.expect(p.is_const); // read-only view
            try std.testing.expectEqual(ds.Event, p.child);
        },
        else => @compileError("eventsView must return a slice type"),
    }
    // TS0-002 (truth finality): these mutations must remain impossible.
    // Uncommenting any of the lines below should fail to compile.
    // events_view[0].event_id = 99;
    // events_view[1] = events_view[0];
}
test "debug_session.test.debugsession_can_be_deterministically_replayed_from_event_log" {
    var dbs_a = ds.DebugSession.init(std.testing.allocator);
    defer dbs_a.deinit();

    try dbs_a.append(.session);
    try dbs_a.append(.command);
    try dbs_a.append(.command);
    try dbs_a.append(.execution);
    try dbs_a.append(.command);

    const original = dbs_a.eventsView();

    var dbs_b = try ds.DebugSession.initFromEvents(std.testing.allocator, original);
    defer dbs_b.deinit();

    const replayed = dbs_b.eventsView();

    try std.testing.expectEqual(original.len, replayed.len);

    for (original, replayed) |o, r| {
        try std.testing.expectEqual(o.event_id, r.event_id);
        try std.testing.expectEqual(o.category, r.category);
    }
}

test "debug_session.snapshot_payload_is_owned_and_copied" {
    var session = ds.DebugSession.init(std.testing.allocator);
    defer session.deinit();

    var buf = [_]u8{ 'a', 'b', 'c' };
    try session.appendSnapshot(.registers, 7, 0, &buf);

    const events = session.eventsView();
    try std.testing.expectEqual(@as(usize, 1), events.len);
    try std.testing.expectEqual(ev.Category.snapshot, events[0].category);

    const snap = events[0].snapshot orelse return error.ExpectedSnapshot;
    try std.testing.expect(snap.payload_owned);
    try std.testing.expectEqual(@as(usize, 3), snap.payload.len);
    try std.testing.expectEqualStrings("abc", snap.payload);

    buf[0] = 'z';
    try std.testing.expectEqualStrings("abc", snap.payload);
}

test "debug_session.appendSnapshot_accepts_empty_payload" {
    var session = ds.DebugSession.init(std.testing.allocator);
    defer session.deinit();

    try session.appendSnapshot(.registers, 2, 1, &.{});
    const events = session.eventsView();
    try std.testing.expectEqual(@as(usize, 1), events.len);

    const snap = events[0].snapshot orelse return error.ExpectedSnapshot;
    try std.testing.expectEqual(@as(usize, 0), snap.payload.len);
    try std.testing.expect(!snap.payload_owned);
}

test "debug_session.snapshot_anchor_is_preserved_on_replay" {
    var session = ds.DebugSession.init(std.testing.allocator);
    defer session.deinit();

    try session.append(.command);
    try session.appendSnapshot(.registers, 1, 0, "raw");

    const original = session.eventsView();
    var replay = try ds.DebugSession.initFromEvents(std.testing.allocator, original);
    defer replay.deinit();

    const replayed = replay.eventsView();
    try std.testing.expectEqual(@as(usize, 2), replayed.len);

    const snap = replayed[1].snapshot orelse return error.ExpectedSnapshot;
    try std.testing.expectEqual(@as(u64, 0), snap.captured_at_event_seq);
    try std.testing.expectEqualStrings("raw", snap.payload);
}

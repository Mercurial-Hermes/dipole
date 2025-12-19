const std = @import("std");
const ds = @import("debug_session.zig");

test "debug_session.test.append_preserves_order_and_ids_are_monotonic" {
    var dbs = ds.DebugSession.init(std.testing.allocator);
    defer dbs.deinit();

    try dbs.append(.session);
    try dbs.append(.session);
    try dbs.append(.session);

    const events_view = dbs.eventsView();

    try std.testing.expectEqual(@as(usize, 3), events_view.len);

    try std.testing.expectEqual(@as(u64, 0), events_view[0].seq);
    try std.testing.expectEqual(@as(u64, 1), events_view[1].seq);
    try std.testing.expectEqual(@as(u64, 2), events_view[2].seq);
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
    // events_view[0].seq = 99;
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
        try std.testing.expectEqual(o.seq, r.seq);
        try std.testing.expectEqual(o.category, r.category);
    }
}

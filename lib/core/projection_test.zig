const std = @import("std");
const ds = @import("debug_session.zig");
const ev = @import("event.zig");
const proj = @import("projection.zig");

fn expectMapsEqual(
    m1: *const std.AutoHashMap(ev.Category, usize),
    m2: *const std.AutoHashMap(ev.Category, usize),
) !void {
    try std.testing.expectEqual(m1.count(), m2.count());

    var it = m1.iterator();
    while (it.next()) |entry| {
        const k = entry.key_ptr.*;
        const v1 = entry.value_ptr.*;
        const v2 = m2.get(k) orelse return error.MissingKey;
        try std.testing.expectEqual(v1, v2);
    }
}

test "projection.eventsCountsByCategory_is_replay_equivalent" {
    var dbs_a = ds.DebugSession.init(std.testing.allocator);
    defer dbs_a.deinit();

    try dbs_a.append(.session);
    try dbs_a.append(.session);
    try dbs_a.append(.session);
    try dbs_a.append(.execution);
    try dbs_a.append(.backend);
    try dbs_a.append(.command);

    const events_original = dbs_a.eventsView();

    var dbs_b = try ds.DebugSession.initFromEvents(std.testing.allocator, events_original);
    defer dbs_b.deinit();

    const events_replayed = dbs_b.eventsView();

    var events_by_cat_a = try proj.eventCountsByCategory(std.testing.allocator, events_original);
    defer events_by_cat_a.deinit();
    var events_by_cat_b = try proj.eventCountsByCategory(std.testing.allocator, events_replayed);
    defer events_by_cat_b.deinit();

    try expectMapsEqual(&events_by_cat_a, &events_by_cat_b);
}

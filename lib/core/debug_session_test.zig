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

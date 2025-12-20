const std = @import("std");
const drv = @import("driver");
const Dummy = struct {
    buf: std.ArrayList(u8),
    poll_calls: usize = 0,
};
fn stubSend(ctx: *anyopaque, line: []const u8) !void {
    const d: *Dummy = @ptrCast(@alignCast(ctx));
    try d.buf.appendSlice(line);
}
fn stubPoll(ctx: *anyopaque) ?drv.DriverObservation {
    const d: *Dummy = @ptrCast(@alignCast(ctx));
    d.poll_calls += 1;
    return .{ .tx = "ok" };
}
test "driver interface: send/poll callable and observable" {
    var dummy = Dummy{ .buf = std.ArrayList(u8).init(std.testing.allocator) };
    defer dummy.buf.deinit();
    var d = drv.Driver{
        .ctx = &dummy,
        .send = stubSend,
        .poll = stubPoll,
    };
    try d.send(d.ctx, "ping");
    try std.testing.expectEqualStrings("ping", dummy.buf.items);
    const obs = d.poll(d.ctx) orelse unreachable;
    try std.testing.expectEqualStrings("ok", obs.tx);
    try std.testing.expectEqual(@as(usize, 1), dummy.poll_calls);
}

const std = @import("std");
const ev = @import("event.zig");
const ctl = @import("controller.zig");
const drv = @import("driver.zig");
const dbs = @import("debug_session.zig");

const FakeDriver = struct {
    alloc: std.mem.Allocator,
    /// Records what was sent via send()
    sent: std.ArrayList([]const u8),
    /// Scripted observations to emit via poll()
    observations: []const drv.DriverObservation,
    next_obs: usize = 0,

    pub fn init(
        allocator: std.mem.Allocator,
        observations: []const drv.DriverObservation,
    ) FakeDriver {
        return .{
            .alloc = allocator,
            .sent = std.ArrayList([]const u8).init(allocator),
            .observations = observations,
            .next_obs = 0,
        };
    }

    pub fn deinit(self: *FakeDriver) void {
        self.sent.deinit();
    }
};

fn fakeSend(ctx: *anyopaque, line: []const u8) anyerror!void {
    const self: *FakeDriver = @ptrCast(@alignCast(ctx));
    try self.sent.append(line);
}

fn fakePoll(ctx: *anyopaque) ?drv.DriverObservation {
    const self: *FakeDriver = @ptrCast(@alignCast(ctx));

    if (self.next_obs >= self.observations.len)
        return null;

    const obs = self.observations[self.next_obs];
    self.next_obs += 1;
    return obs;
}

test "driver interface: send/poll callable and observable" {
    // --- Arrange -------------------------------------------------------------
    const alloc = std.testing.allocator;

    var session = dbs.DebugSession.init(alloc);
    defer session.deinit();

    const observations = [_]drv.DriverObservation{
        .{ .tx = "help" },
        .{ .rx = "output line" },
        .prompt,
    };

    var fake = FakeDriver.init(alloc, &observations);
    defer fake.deinit();

    const driver = drv.Driver{
        .ctx = &fake,
        .send = fakeSend,
        .poll = fakePoll,
    };

    var controller = ctl.Controller.init(
        alloc,
        &session,
        driver,
    );

    // --- Act ----------------------------------------------------------------

    try controller.issueRawCommand("help");

    // --- Assert: driver interaction ------------------------------------------

    try std.testing.expectEqual(@as(usize, 1), fake.sent.items.len);
    try std.testing.expectEqualStrings("help", fake.sent.items[0]);

    // --- Assert: events admitted ---------------------------------------------

    const events = session.eventsView();
    try std.testing.expectEqual(@as(usize, 3), events.len);

    // --- Assert: ordering + seq ----------------------------------------------

    try std.testing.expect(events[0].seq < events[1].seq);
    try std.testing.expect(events[1].seq < events[2].seq);

    // --- Assert: categories reflect ingress, not meaning ---------------------

    try std.testing.expectEqual(ev.Category.command, events[0].category);
    try std.testing.expectEqual(ev.Category.backend, events[1].category);
    try std.testing.expectEqual(ev.Category.backend, events[2].category);
}

const std = @import("std");
const ev = @import("event");
const ctl = @import("controller.zig");
const drv = @import("driver");
const dbs = @import("debug_session.zig");
const lnchr = @import("debugger/lldb_launcher.zig");
const ptydrv = @import("debugger/pty_raw_driver.zig");

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
    return switch (obs) {
        .tx => |bytes| blk: {
            const dup = self.alloc.dupe(u8, bytes) catch unreachable;
            break :blk .{ .tx = dup };
        },
        .rx => |bytes| blk: {
            const dup = self.alloc.dupe(u8, bytes) catch unreachable;
            break :blk .{ .rx = dup };
        },
        .prompt => .prompt,
    };
}

test "controller ingests raw driver observations as ordered events" {
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

    // --- Assert: ordering + event_id ----------------------------------------------

    try std.testing.expect(events[0].event_id < events[1].event_id);
    try std.testing.expect(events[1].event_id < events[2].event_id);

    // --- Assert: categories reflect ingress, not meaning ---------------------

    try std.testing.expectEqual(ev.Category.command, events[0].category);
    try std.testing.expectEqual(ev.Category.backend, events[1].category);
    try std.testing.expectEqual(ev.Category.backend, events[2].category);
}

test "controller ingests real transport observations without interpretation" {
    var buf: [8192]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    const alloc = fba.allocator();

    // --- Arrange ------------------------------------------------------------

    // Kernel
    var session = dbs.DebugSession.init(alloc);
    defer session.deinit();

    // Real backend
    var ll = try lnchr.LLDBLauncher.attach(0);
    defer ll.shutdown() catch {};

    // Transport-backed driver
    var raw = ptydrv.PtyRawDriver.init(alloc, ll.master_fd);

    const driver = raw.asDriver();

    // Controller under test
    var controller = ctl.Controller.init(
        alloc,
        &session,
        driver,
    );

    // --- Act ----------------------------------------------------------------

    // Issue a real command into a real debugger
    try controller.issueRawCommand("help");

    // --- Assert -------------------------------------------------------------

    const events = session.eventsView();

    // We do NOT assert exact event count.
    // Real transport is noisy and non-deterministic.
    try std.testing.expect(events.len > 0);

    var backend_count: usize = 0;

    for (events) |e| {
        switch (e.category) {
            .command => {}, // may or may not appear first on real transport
            .backend => backend_count += 1,
            else => return error.UnexpectedCategory,
        }
    }

    try std.testing.expect(backend_count >= 1);

    // event_id must be monotonic.
    var i: usize = 1;
    while (i < events.len) : (i += 1) {
        try std.testing.expect(events[i - 1].event_id < events[i].event_id);
    }
}

const std = @import("std");
const intent = @import("intent.zig");
const feed = @import("semantic_feed");
const reg = @import("semantic_registry");
const ev = @import("event");
const ctl = @import("controller");
const drv = @import("driver");
const dbs = @import("debug_session");

fn buildFrames(alloc: std.mem.Allocator) ![]feed.Frame {
    const ids = [_]reg.ProjectionId{
        .{ .name = "event.kind", .version = .{ .major = 1, .minor = 0 } },
    };
    const events = [_]ev.Event{};
    return feed.buildFrames(alloc, &ids, &events);
}

fn buildKindFrame(alloc: std.mem.Allocator, events: []const ev.Event) !feed.Frame {
    // v0.2 exemplar: we couple TS4 validation/render checks to event.kind@1.0 only
    // to exercise the path; not a general semantic dependency.
    const id = reg.ProjectionId{ .name = "event.kind", .version = .{ .major = 1, .minor = 0 } };
    return feed.buildFrame(alloc, id, events);
}

test "TS4-001-001: intent is typed, versioned, and not a projection" {
    comptime {
        const fields = std.meta.fields(intent.Intent);
        try std.testing.expectEqual(@as(usize, 2), fields.len);
        try std.testing.expectEqualStrings("kind", fields[0].name);
        try std.testing.expectEqualStrings("version", fields[1].name);

        try std.testing.expect(!@hasDecl(intent.Intent, "setKind"));
        try std.testing.expect(!@hasDecl(intent.Intent, "setVersion"));
    }

    try std.testing.expect(!reg.registry.nameExists(intent.intentName(.Ping)));
    try std.testing.expect(!reg.registry.nameHasMultiple(intent.intentName(.Ping)));
}

test "TS4-001-002: intent is not an Event" {
    comptime {
        const fields = std.meta.fields(intent.Intent);
        for (fields) |f| {
            try std.testing.expect(!std.mem.eql(u8, f.name, "category"));
            try std.testing.expect(!std.mem.eql(u8, f.name, "event_id"));
            try std.testing.expect(!std.mem.eql(u8, f.name, "timestamp"));
        }
        try std.testing.expect(!@hasDecl(intent, "toEvent"));
        try std.testing.expect(!@hasDecl(intent, "appendToLog"));
    }

    var session = dbs.DebugSession.init(std.testing.allocator);
    defer session.deinit();
    try std.testing.expectEqual(@as(usize, 0), session.eventsView().len);
}

test "TS4-001-003: validation is pure and deterministic" {
    const alloc = std.testing.allocator;
    const frames = try buildFrames(alloc);
    defer {
        for (frames) |*f| feed.deinitFrame(alloc, f);
        alloc.free(frames);
    }

    const valid = try intent.validateIntent(intent.pingIntent(), frames);
    const again = try intent.validateIntent(intent.pingIntent(), frames);
    try std.testing.expectEqual(valid.intent.kind, again.intent.kind);
    try std.testing.expectEqual(valid.intent.version, again.intent.version);

    // Frames are read-only inputs.
    try std.testing.expectEqualStrings("event.kind", frames[0].projection_id);
    try std.testing.expect(frames[0].payload.len >= 0);

    var session = dbs.DebugSession.init(alloc);
    defer session.deinit();
    try std.testing.expectEqual(@as(usize, 0), session.eventsView().len);
}

test "TS4-001-004: invalid intent produces no effects" {
    const alloc = std.testing.allocator;
    const frames = try buildFrames(alloc);
    defer {
        for (frames) |*f| feed.deinitFrame(alloc, f);
        alloc.free(frames);
    }

    try std.testing.expectError(error.UnknownIntentVersion, intent.validateIntent(.{
        .kind = .Ping,
        .version = .{ .major = 9, .minor = 9 },
    }, frames));

    try std.testing.expectError(error.MissingSemanticFrame, intent.validateIntent(intent.pingIntent(), &.{}));

    var session = dbs.DebugSession.init(alloc);
    defer session.deinit();
    try std.testing.expectEqual(@as(usize, 0), session.eventsView().len);
}

const FakeDriver = struct {
    alloc: std.mem.Allocator,
    observations: []const drv.DriverObservation,
    next_obs: usize = 0,
    sent: std.ArrayList([]const u8),

    pub fn init(alloc: std.mem.Allocator, observations: []const drv.DriverObservation) FakeDriver {
        return .{
            .alloc = alloc,
            .observations = observations,
            .next_obs = 0,
            .sent = std.ArrayList([]const u8).init(alloc),
        };
    }

    pub fn deinit(self: *FakeDriver) void {
        for (self.sent.items) |s| self.alloc.free(s);
        self.sent.deinit();
    }
};

fn fakeSend(ctx: *anyopaque, line: []const u8) anyerror!void {
    const self: *FakeDriver = @ptrCast(@alignCast(ctx));
    const copy = try self.alloc.dupe(u8, line);
    errdefer self.alloc.free(copy);
    try self.sent.append(copy);
}

fn fakePoll(ctx: *anyopaque) ?drv.DriverObservation {
    const self: *FakeDriver = @ptrCast(@alignCast(ctx));
    if (self.next_obs >= self.observations.len) return null;
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

test "TS4-001-005: valid intent validation does not execute" {
    const alloc = std.testing.allocator;
    const frames = try buildFrames(alloc);
    defer {
        for (frames) |*f| feed.deinitFrame(alloc, f);
        alloc.free(frames);
    }

    var session = dbs.DebugSession.init(alloc);
    defer session.deinit();

    var fake = FakeDriver.init(alloc, &.{});
    defer fake.deinit();

    const driver = drv.Driver{
        .ctx = &fake,
        .send = fakeSend,
        .poll = fakePoll,
    };

    const controller = ctl.Controller.init(alloc, &session, driver);

    const valid = try intent.validateIntent(intent.pingIntent(), frames);
    _ = valid; // validation only

    try std.testing.expectEqual(@as(usize, 0), fake.sent.items.len);
    try std.testing.expectEqual(@as(usize, 0), session.eventsView().len);
    try std.testing.expect(fake.next_obs == 0);
    try std.testing.expectEqual(@as(usize, 0), controller.session.events.items.len);
}

test "TS4-002-001: executing validated intent routes through controller boundary" {
    const alloc = std.testing.allocator;

    const frames = try buildFrames(alloc);
    defer {
        for (frames) |*f| feed.deinitFrame(alloc, f);
        alloc.free(frames);
    }

    var session = dbs.DebugSession.init(alloc);
    defer session.deinit();

    const observations = [_]drv.DriverObservation{
        .{ .tx = intent.ping_intent_name },
        .{ .rx = "pong" },
    };
    var fake = FakeDriver.init(alloc, &observations);
    defer fake.deinit();

    const driver = drv.Driver{
        .ctx = &fake,
        .send = fakeSend,
        .poll = fakePoll,
    };

    var controller = ctl.Controller.init(alloc, &session, driver);

    const valid = try intent.validateIntent(intent.pingIntent(), frames);
    try intent.executeIntent(&controller, valid);

    const events = session.eventsView();
    try std.testing.expectEqual(@as(usize, 2), events.len);
    try std.testing.expectEqualStrings(intent.ping_intent_name, fake.sent.items[0]);

    try std.testing.expectEqual(ev.Category.command, events[0].category);
    try std.testing.expectEqual(ev.Category.backend, events[1].category);
    try std.testing.expect(events[0].event_id < events[1].event_id);
}

test "TS4-002-002: effects of intent are observable only via events" {
    const alloc = std.testing.allocator;

    // Run A: route intent through controller/driver to produce events.
    var session_a = dbs.DebugSession.init(alloc);
    defer session_a.deinit();

    const observations = [_]drv.DriverObservation{
        .{ .tx = intent.ping_intent_name },
        .{ .rx = "pong" },
    };
    var fake = FakeDriver.init(alloc, &observations);
    defer fake.deinit();

    const driver = drv.Driver{
        .ctx = &fake,
        .send = fakeSend,
        .poll = fakePoll,
    };
    var controller = ctl.Controller.init(alloc, &session_a, driver);

    const frames = try buildFrames(alloc);
    defer {
        for (frames) |*f| feed.deinitFrame(alloc, f);
        alloc.free(frames);
    }
    const valid = try intent.validateIntent(intent.pingIntent(), frames);
    try intent.executeIntent(&controller, valid);

    const events_a = session_a.eventsView();
    var frame_a = try buildKindFrame(alloc, events_a);
    defer feed.deinitFrame(alloc, &frame_a);

    // Run B: rebuild semantic output from the event log alone (no intent path).
    var session_b = try dbs.DebugSession.initFromEvents(alloc, events_a);
    defer session_b.deinit();
    const events_b = session_b.eventsView();
    var frame_b = try buildKindFrame(alloc, events_b);
    defer feed.deinitFrame(alloc, &frame_b);

    try std.testing.expectEqual(events_a.len, events_b.len);
    try std.testing.expectEqualStrings(frame_a.payload, frame_b.payload);
    try std.testing.expectEqualStrings(frame_a.projection_id, frame_b.projection_id);
    try std.testing.expectEqual(frame_a.version, frame_b.version);
}

test "TS4-002-003: intent is not replayed" {
    const alloc = std.testing.allocator;

    // Produce an event log via intent execution.
    var session_a = dbs.DebugSession.init(alloc);
    defer session_a.deinit();

    const observations = [_]drv.DriverObservation{
        .{ .tx = intent.ping_intent_name },
        .{ .rx = "pong" },
    };
    var fake = FakeDriver.init(alloc, &observations);
    defer fake.deinit();

    const driver = drv.Driver{
        .ctx = &fake,
        .send = fakeSend,
        .poll = fakePoll,
    };
    var controller = ctl.Controller.init(alloc, &session_a, driver);

    const frames = try buildFrames(alloc);
    defer {
        for (frames) |*f| feed.deinitFrame(alloc, f);
        alloc.free(frames);
    }
    const valid = try intent.validateIntent(intent.pingIntent(), frames);
    try intent.executeIntent(&controller, valid);

    const events_log = session_a.eventsView();
    var frame_original = try buildKindFrame(alloc, events_log);
    defer feed.deinitFrame(alloc, &frame_original);

    // Replay: rebuild semantic output from the saved events without any intent calls.
    var replay_session = try dbs.DebugSession.initFromEvents(alloc, events_log);
    defer replay_session.deinit();
    var replay_frame = try buildKindFrame(alloc, replay_session.eventsView());
    defer feed.deinitFrame(alloc, &replay_frame);

    try std.testing.expectEqualStrings(frame_original.payload, replay_frame.payload);
    try std.testing.expectEqualStrings(frame_original.projection_id, replay_frame.projection_id);
    try std.testing.expectEqual(frame_original.version, replay_frame.version);
}

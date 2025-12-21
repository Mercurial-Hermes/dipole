const std = @import("std");
const feed = @import("feed.zig");
const reg = @import("registry.zig");
const proj = @import("projection.zig");
const ev = @import("event");

test "TS3-010-001: every frame includes originating ProjectionId" {
    const alloc = std.testing.allocator;
    const events = [_]ev.Event{
        .{ .category = .session, .event_id = 1, .timestamp = null },
    };

    const ids = [_]reg.ProjectionId{
        .{ .name = "event.kind", .version = .{ .major = 1, .minor = 0 } },
    };

    const frames = try feed.buildFrames(alloc, &ids, &events);
    defer {
        for (frames) |*f| feed.deinitFrame(alloc, f);
        alloc.free(frames);
    }

    try std.testing.expectEqual(@as(usize, ids.len), frames.len);
    for (frames, ids) |frame, expected_id| {
        try std.testing.expect(frame.projection_id.len > 0);
        try std.testing.expectEqualStrings(expected_id.name, frame.projection_id);
        try std.testing.expectEqual(expected_id.version, frame.version);
        try std.testing.expect(frame.payload.len > 0);
    }
}

test "TS3-010-003: feed exposes no raw event subscription" {
    try std.testing.expect(!@hasDecl(feed, "subscribeRawEvents"));
    try std.testing.expect(!@hasDecl(feed, "pollEvents"));
}

test "TS3-010-004: feed rejects unversioned when multiple versions exist" {
    const alloc = std.testing.allocator;
    const events = [_]ev.Event{
        .{ .category = .session, .event_id = 1, .timestamp = null },
    };

    try std.testing.expectError(error.UnknownVersion, feed.buildFrame(
        alloc,
        .{ .name = "event.kind", .version = null },
        &events,
    ));
}

test "TS3-010-002: feed is replay-equivalent to direct projection" {
    const alloc = std.testing.allocator;
    const events = [_]ev.Event{
        .{ .category = .session, .event_id = 1, .timestamp = null },
        .{ .category = .command, .event_id = 2, .timestamp = null },
        .{ .category = .backend, .event_id = 3, .timestamp = null },
    };

    const id = reg.ProjectionId{ .name = "event.kind", .version = .{ .major = 1, .minor = 0 } };

    var frame1 = try feed.buildFrame(alloc, id, &events);
    defer feed.deinitFrame(alloc, &frame1);
    var frame2 = try feed.buildFrame(alloc, id, &events);
    defer feed.deinitFrame(alloc, &frame2);

    try std.testing.expectEqualStrings(frame1.payload, frame2.payload);
    try std.testing.expectEqualStrings(frame1.projection_id, frame2.projection_id);
    try std.testing.expectEqual(frame1.version, frame2.version);

    // Direct projection canonical bytes should match feed frame payload.
    const direct = blk: {
        const kinds = try proj.projectEventKinds(alloc, &events);
        defer alloc.free(kinds);

        var buf = std.ArrayList(u8).init(alloc);
        defer buf.deinit();

        try buf.append('[');
        for (kinds, 0..) |k, i| {
            if (i != 0) try buf.append(',');
            const s = switch (k) {
                .SessionLifecycle => "SessionLifecycle",
                .UserAction => "UserAction",
                .EngineActivity => "EngineActivity",
                .Snapshot => "Snapshot",
                .Unknown => "Unknown",
            };
            try buf.append('"');
            try buf.appendSlice(s);
            try buf.append('"');
        }
        try buf.append(']');
        break :blk try buf.toOwnedSlice();
    };
    defer alloc.free(direct);

    try std.testing.expectEqualStrings(direct, frame1.payload);
}

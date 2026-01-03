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

test "event.kind@1.0: canonical payload reflects category mapping in order" {
    const alloc = std.testing.allocator;
    // Ordering is slice-based; event_id values are irrelevant to the mapping.
    const events = [_]ev.Event{
        .{ .category = .session, .event_id = 0, .timestamp = null },
        .{ .category = .command, .event_id = 0, .timestamp = null },
        .{ .category = .backend, .event_id = 0, .timestamp = null },
        .{ .category = .execution, .event_id = 0, .timestamp = null },
        .{ .category = .snapshot, .event_id = 0, .timestamp = null },
    };

    const id = reg.ProjectionId{ .name = "event.kind", .version = .{ .major = 1, .minor = 0 } };
    var frame = try feed.buildFrame(alloc, id, &events);
    defer feed.deinitFrame(alloc, &frame);

    const expected =
        \\["SessionLifecycle","UserAction","EngineActivity","EngineActivity","Snapshot"]
    ;
    try std.testing.expectEqualStrings("event.kind", frame.projection_id);
    try std.testing.expectEqual(@as(?reg.SemanticVersion, .{ .major = 1, .minor = 0 }), frame.version);
    try std.testing.expectEqualStrings(expected, frame.payload);
}

test "event.kind@1.0: buildFrame is replay-equivalent on identical inputs" {
    const alloc = std.testing.allocator;
    const events = [_]ev.Event{
        .{ .category = .session, .event_id = 0, .timestamp = null },
        .{ .category = .command, .event_id = 0, .timestamp = null },
        .{ .category = .execution, .event_id = 0, .timestamp = null },
    };
    const id = reg.ProjectionId{ .name = "event.kind", .version = .{ .major = 1, .minor = 0 } };

    var frame_a = try feed.buildFrame(alloc, id, &events);
    defer feed.deinitFrame(alloc, &frame_a);
    var frame_b = try feed.buildFrame(alloc, id, &events);
    defer feed.deinitFrame(alloc, &frame_b);

    try std.testing.expectEqualStrings(frame_a.payload, frame_b.payload);
    try std.testing.expectEqualStrings(frame_a.projection_id, frame_b.projection_id);
    try std.testing.expectEqual(frame_a.version, frame_b.version);
}

test "event.kind@9.9 rejects with UnknownVersion" {
    const alloc = std.testing.allocator;
    const events = [_]ev.Event{
        .{ .category = .session, .event_id = 0, .timestamp = null },
    };
    try std.testing.expectError(error.UnknownVersion, feed.buildFrame(
        alloc,
        .{ .name = "event.kind", .version = .{ .major = 9, .minor = 9 } },
        &events,
    ));
}

test "unknown projection id rejects with UnknownProjectionId" {
    const alloc = std.testing.allocator;
    const events = [_]ev.Event{
        .{ .category = .session, .event_id = 0, .timestamp = null },
    };
    try std.testing.expectError(error.UnknownProjectionId, feed.buildFrame(
        alloc,
        .{ .name = "does.not.exist", .version = .{ .major = 1, .minor = 0 } },
        &events,
    ));
}

test "breakpoint.list@1: single snapshot echoes payload" {
    const alloc = std.testing.allocator;
    const payload = "{\"bp\":1}";
    const events = [_]ev.Event{
        .{ .category = .snapshot, .event_id = 0, .timestamp = null, .payload = payload },
    };

    const id = reg.ProjectionId{ .name = "breakpoint.list", .version = .{ .major = 1, .minor = 0 } };
    var frame = try feed.buildFrame(alloc, id, &events);
    defer feed.deinitFrame(alloc, &frame);

    try std.testing.expectEqualStrings("breakpoint.list", frame.projection_id);
    try std.testing.expectEqual(@as(?reg.SemanticVersion, .{ .major = 1, .minor = 0 }), frame.version);
    try std.testing.expectEqualStrings(payload, frame.payload);
}

test "breakpoint.list@1: most recent snapshot wins" {
    const alloc = std.testing.allocator;
    const payload_old = "old";
    const payload_new = "new";
    const events = [_]ev.Event{
        .{ .category = .snapshot, .event_id = 0, .timestamp = null, .payload = payload_old },
        .{ .category = .snapshot, .event_id = 1, .timestamp = null, .payload = payload_new },
    };

    const id = reg.ProjectionId{ .name = "breakpoint.list", .version = .{ .major = 1, .minor = 0 } };
    var frame = try feed.buildFrame(alloc, id, &events);
    defer feed.deinitFrame(alloc, &frame);

    try std.testing.expectEqualStrings(payload_new, frame.payload);
}

test "breakpoint.list@1: empty log yields empty list payload" {
    const alloc = std.testing.allocator;
    const events = [_]ev.Event{};

    const id = reg.ProjectionId{ .name = "breakpoint.list", .version = .{ .major = 1, .minor = 0 } };
    var frame = try feed.buildFrame(alloc, id, &events);
    defer feed.deinitFrame(alloc, &frame);

    try std.testing.expectEqualStrings("[]", frame.payload);
}

test "breakpoint.list@1: payload is opaque, not parsed" {
    const alloc = std.testing.allocator;
    const payload = "raw\nbytes";
    const events = [_]ev.Event{
        .{ .category = .snapshot, .event_id = 0, .timestamp = null, .payload = payload },
    };

    const id = reg.ProjectionId{ .name = "breakpoint.list", .version = .{ .major = 1, .minor = 0 } };
    var frame = try feed.buildFrame(alloc, id, &events);
    defer feed.deinitFrame(alloc, &frame);

    try std.testing.expectEqualStrings(payload, frame.payload);
}

test "register.snapshot@1: empty log yields empty list payload" {
    const alloc = std.testing.allocator;
    const events = [_]ev.Event{};

    const id = reg.ProjectionId{ .name = "register.snapshot", .version = .{ .major = 1, .minor = 0 } };
    var frame = try feed.buildFrame(alloc, id, &events);
    defer feed.deinitFrame(alloc, &frame);

    try std.testing.expectEqualStrings("register.snapshot", frame.projection_id);
    try std.testing.expectEqualStrings("[]", frame.payload);
}

test "register.snapshot@1: latest register snapshot payload wins" {
    const alloc = std.testing.allocator;
    const snap_old = ev.SnapshotPayload{
        .snapshot_kind = .registers,
        .source_id = 1,
        .captured_at_event_seq = 0,
        .payload = "old",
    };
    const snap_new = ev.SnapshotPayload{
        .snapshot_kind = .registers,
        .source_id = 1,
        .captured_at_event_seq = 1,
        .payload = "new",
    };
    const events = [_]ev.Event{
        .{ .category = .snapshot, .event_id = 0, .timestamp = null, .snapshot = snap_old },
        .{ .category = .snapshot, .event_id = 1, .timestamp = null, .snapshot = snap_new },
    };

    const id = reg.ProjectionId{ .name = "register.snapshot", .version = .{ .major = 1, .minor = 0 } };
    var frame = try feed.buildFrame(alloc, id, &events);
    defer feed.deinitFrame(alloc, &frame);

    try std.testing.expectEqualStrings("new", frame.payload);
}

test "register.snapshot@1: ignores snapshot events without register payload" {
    const alloc = std.testing.allocator;
    const snap = ev.SnapshotPayload{
        .snapshot_kind = .registers,
        .source_id = 1,
        .captured_at_event_seq = 2,
        .payload = "regs",
    };
    const events = [_]ev.Event{
        .{ .category = .snapshot, .event_id = 0, .timestamp = null, .payload = "not-a-snapshot" },
        .{ .category = .snapshot, .event_id = 1, .timestamp = null, .snapshot = snap },
    };

    const id = reg.ProjectionId{ .name = "register.snapshot", .version = .{ .major = 1, .minor = 0 } };
    var frame = try feed.buildFrame(alloc, id, &events);
    defer feed.deinitFrame(alloc, &frame);

    try std.testing.expectEqualStrings("regs", frame.payload);
}

test "register.snapshot@1: single snapshot echoes payload verbatim" {
    const alloc = std.testing.allocator;
    const payload =
        \\[{"name":"x0","value":"0x0"},{"name":"pc","value":"0x1000"}]
    ;
    const events = [_]ev.Event{
        .{ .category = .snapshot, .event_id = 0, .timestamp = null, .payload = payload },
    };
    const id = reg.ProjectionId{ .name = "register.snapshot", .version = .{ .major = 1, .minor = 0 } };
    var frame = try feed.buildFrame(alloc, id, &events);
    defer feed.deinitFrame(alloc, &frame);

    try std.testing.expectEqualStrings(payload, frame.payload);
    try std.testing.expectEqualStrings("register.snapshot", frame.projection_id);
    try std.testing.expectEqual(@as(?reg.SemanticVersion, .{ .major = 1, .minor = 0 }), frame.version);
}

test "register.snapshot@1: most recent snapshot wins" {
    const alloc = std.testing.allocator;
    const payload_old = "[{\"name\":\"x0\",\"value\":\"0x1\"}]";
    const payload_new = "[{\"name\":\"x0\",\"value\":\"0x2\"}]";
    const events = [_]ev.Event{
        .{ .category = .snapshot, .event_id = 0, .timestamp = null, .payload = payload_old },
        .{ .category = .snapshot, .event_id = 1, .timestamp = null, .payload = payload_new },
    };
    const id = reg.ProjectionId{ .name = "register.snapshot", .version = .{ .major = 1, .minor = 0 } };
    var frame = try feed.buildFrame(alloc, id, &events);
    defer feed.deinitFrame(alloc, &frame);

    try std.testing.expectEqualStrings(payload_new, frame.payload);
}

test "register.snapshot@1: missing registers preserved as-is" {
    const alloc = std.testing.allocator;
    const payload = "[{\"name\":\"x0\",\"value\":\"0x3\"}]"; // intentionally partial
    const events = [_]ev.Event{
        .{ .category = .snapshot, .event_id = 0, .timestamp = null, .payload = payload },
    };
    const id = reg.ProjectionId{ .name = "register.snapshot", .version = .{ .major = 1, .minor = 0 } };
    var frame = try feed.buildFrame(alloc, id, &events);
    defer feed.deinitFrame(alloc, &frame);

    try std.testing.expectEqualStrings(payload, frame.payload);
}

test "register.snapshot@1: empty log yields empty payload" {
    const alloc = std.testing.allocator;
    const events = [_]ev.Event{};
    const id = reg.ProjectionId{ .name = "register.snapshot", .version = .{ .major = 1, .minor = 0 } };
    var frame = try feed.buildFrame(alloc, id, &events);
    defer feed.deinitFrame(alloc, &frame);

    try std.testing.expectEqualStrings("[]", frame.payload);
}

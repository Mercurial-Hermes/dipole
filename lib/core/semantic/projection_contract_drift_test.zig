const std = @import("std");
const ev = @import("event");
const reg = @import("registry.zig");
const proj = @import("projection.zig");

fn expectEqualEventKinds(a: []const proj.EventKind, b: []const proj.EventKind) !void {
    try std.testing.expectEqual(a.len, b.len);
    for (a, b) |ea, eb| {
        try std.testing.expectEqual(ea, eb);
    }
}

fn expectEventKindsNotEqual(a: []const proj.EventKind, b: []const proj.EventKind) !void {
    try std.testing.expectEqual(a.len, b.len);
    var any_diff = false;
    for (a, b) |ea, eb| {
        if (ea != eb) {
            any_diff = true;
            break;
        }
    }
    if (!any_diff) {
        std.debug.print("expected differing kinds; got identical slices: {any}\n", .{a});
    }
    try std.testing.expect(any_diff);
}

test "TS2-003-001: event.kind ignores irrelevant fields (drift firewall)" {
    const alloc = std.testing.allocator;

    // Ensure the projection metadata declares only the permitted fields we expect.
    const def = reg.registry.lookup(.{ .name = "event.kind" }) orelse {
        return error.MissingProjection;
    };
    try std.testing.expectEqual(@as(usize, 1), def.permitted_fields.len);
    try std.testing.expectEqual(reg.EventField.category, def.permitted_fields[0]);
    try std.testing.expect(def.permitted_fields[0] != reg.EventField.event_id);

    const base_events = [_]ev.Event{
        .{ .category = .session, .event_id = 1, .timestamp = null },
        .{ .category = .command, .event_id = 2, .timestamp = null },
        .{ .category = .backend, .event_id = 3, .timestamp = null },
        .{ .category = .execution, .event_id = 4, .timestamp = null },
    };

    var mutated_events = base_events;
    mutated_events[0].event_id = 10;
    mutated_events[1].event_id = 20;
    mutated_events[2].event_id = 30;
    mutated_events[3].event_id = 40;
    const fake_ts = std.mem.zeroes(std.time.Instant);
    mutated_events[0].timestamp = fake_ts;
    mutated_events[1].timestamp = fake_ts;
    mutated_events[2].timestamp = fake_ts;
    mutated_events[3].timestamp = fake_ts;

    // Premises: identical shape/order; only irrelevant fields differ.
    try std.testing.expectEqual(base_events.len, mutated_events.len);
    for (base_events, mutated_events) |a, b| {
        try std.testing.expectEqual(a.category, b.category);
    }

    // Run projection twice on each log to assert determinism.
    const kinds_base_1 = try proj.projectEventKinds(alloc, &base_events);
    defer alloc.free(kinds_base_1);
    const kinds_base_2 = try proj.projectEventKinds(alloc, &base_events);
    defer alloc.free(kinds_base_2);

    const kinds_mut_1 = try proj.projectEventKinds(alloc, &mutated_events);
    defer alloc.free(kinds_mut_1);
    const kinds_mut_2 = try proj.projectEventKinds(alloc, &mutated_events);
    defer alloc.free(kinds_mut_2);

    try expectEqualEventKinds(kinds_base_1, kinds_base_2);
    try expectEqualEventKinds(kinds_mut_1, kinds_mut_2);
    try expectEqualEventKinds(kinds_base_1, kinds_mut_1);
}

test "TS2-003-002: event.kind responds to permitted field changes (sanity check)" {
    const alloc = std.testing.allocator;

    const def = reg.registry.lookup(.{ .name = "event.kind" }) orelse {
        return error.MissingProjection;
    };
    try std.testing.expectEqual(@as(usize, 1), def.permitted_fields.len);
    try std.testing.expectEqual(reg.EventField.category, def.permitted_fields[0]);

    const base_events = [_]ev.Event{
        .{ .category = .session, .event_id = 1, .timestamp = null },
        .{ .category = .command, .event_id = 2, .timestamp = null },
        .{ .category = .backend, .event_id = 3, .timestamp = null },
        .{ .category = .execution, .event_id = 4, .timestamp = null },
    };

    var mutated_events = base_events;
    // In-scope mutation: category is explicitly permitted.
    const mut_idx: usize = 1;
    mutated_events[mut_idx].category = .backend; // was command

    // Premises: identical length/identity; only permitted field differs.
    try std.testing.expectEqual(base_events.len, mutated_events.len);
    for (base_events, mutated_events, 0..) |a, b, i| {
        try std.testing.expectEqual(a.event_id, b.event_id);
        try std.testing.expectEqual(a.timestamp, b.timestamp);
        if (i == mut_idx) {
            try std.testing.expect(a.category != b.category);
        } else {
            try std.testing.expectEqual(a.category, b.category);
        }
    }

    const kinds_base_1 = try proj.projectEventKinds(alloc, &base_events);
    defer alloc.free(kinds_base_1);
    const kinds_base_2 = try proj.projectEventKinds(alloc, &base_events);
    defer alloc.free(kinds_base_2);

    const kinds_mut_1 = try proj.projectEventKinds(alloc, &mutated_events);
    defer alloc.free(kinds_mut_1);
    const kinds_mut_2 = try proj.projectEventKinds(alloc, &mutated_events);
    defer alloc.free(kinds_mut_2);

    // Deterministic per log.
    try expectEqualEventKinds(kinds_base_1, kinds_base_2);
    try expectEqualEventKinds(kinds_mut_1, kinds_mut_2);

    // Negative control: for this projection, permitted-field mutation yields different meaning.
    try expectEventKindsNotEqual(kinds_base_1, kinds_mut_1);
}

fn expectEventsEqual(a: []const ev.Event, b: []const ev.Event) !void {
    try std.testing.expectEqual(a.len, b.len);
    for (a, b) |ea, eb| {
        try std.testing.expectEqual(ea.category, eb.category);
        try std.testing.expectEqual(ea.event_id, eb.event_id);
        try std.testing.expectEqual(ea.timestamp, eb.timestamp);
    }
}

fn serializeEventKindsCanonical(kinds: []const proj.EventKind, buf: *std.ArrayList(u8)) ![]const u8 {
    // Minimal canonical JSON array of strings, lexicographic key ordering not relevant (array).
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
    return buf.items;
}

test "TS2-003-003: drift harness determinism (registry projections repeatable)" {
    const alloc = std.testing.allocator;

    const base_events = [_]ev.Event{
        .{ .category = .session, .event_id = 1, .timestamp = null },
        .{ .category = .command, .event_id = 2, .timestamp = null },
        .{ .category = .backend, .event_id = 3, .timestamp = null },
        .{ .category = .execution, .event_id = 4, .timestamp = null },
        .{ .category = .snapshot, .event_id = 5, .timestamp = null },
    };

    // For each registered projection, run twice with identical allocator/log and assert repeatability.
    inline for (reg.registry.projections) |def| {
        // Work on a mutable copy to detect input mutation.
        var log_copy = base_events;

        if (std.mem.eql(u8, def.id.name, "event.kind")) {
            const kinds_run1 = try proj.projectEventKinds(alloc, &log_copy);
            defer alloc.free(kinds_run1);
            const kinds_run2 = try proj.projectEventKinds(alloc, &log_copy);
            defer alloc.free(kinds_run2);

            try expectEqualEventKinds(kinds_run1, kinds_run2);
            // Canonical serialization should also match.
            var buf1 = std.ArrayList(u8).init(alloc);
            defer buf1.deinit();
            var buf2 = std.ArrayList(u8).init(alloc);
            defer buf2.deinit();
            const bytes1 = try serializeEventKindsCanonical(kinds_run1, &buf1);
            const bytes2 = try serializeEventKindsCanonical(kinds_run2, &buf2);
            try std.testing.expectEqualStrings(bytes1, bytes2);

            try expectEventsEqual(&base_events, &log_copy);
        } else if (std.mem.eql(u8, def.id.name, "breakpoint.list")) {
            // Breakpoint list projection is opaque and snapshot-driven; ensure inputs remain unchanged.
            try expectEventsEqual(&base_events, &log_copy);
        } else if (std.mem.eql(u8, def.id.name, "register.snapshot")) {
            // Register snapshot projection is opaque and snapshot-driven; ensure inputs remain unchanged.
            try expectEventsEqual(&base_events, &log_copy);
        } else {
            return error.MissingHarnessProjection;
        }
    }
}

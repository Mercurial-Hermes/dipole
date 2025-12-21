const std = @import("std");
const reg = @import("registry.zig");
const ui = @import("ui_adapter.zig");

fn frame(id: reg.ProjectionId, payload: []const u8) ui.Frame {
    return .{ .projection_id = id.name, .version = id.version, .payload = payload };
}

test "TS3-UI-001-001: adapter renders frame for configured ProjectionId" {
    const alloc = std.testing.allocator;
    const adapter = ui.UiAdapter{
        .projection_id = .{ .name = "event.kind", .version = .{ .major = 1, .minor = 0 } },
    };

    const f = frame(adapter.projection_id, "[]");
    var out = try adapter.render(alloc, f);
    defer ui.deinitRenderOutput(alloc, &out);

    try std.testing.expectEqualStrings("event.kind", out.title);
    try std.testing.expectEqual(@as(usize, 1), out.sections.len);
    try std.testing.expectEqual(@as(usize, 1), out.sections[0].rows.len);
    try std.testing.expectEqualStrings("payload", out.sections[0].rows[0].label);
    try std.testing.expectEqualStrings("[]", out.sections[0].rows[0].value);
}

test "TS3-UI-001-002: adapter rejects version mismatch" {
    const alloc = std.testing.allocator;
    const adapter = ui.UiAdapter{
        .projection_id = .{ .name = "event.kind", .version = .{ .major = 1, .minor = 0 } },
    };

    const mismatched = frame(.{ .name = "event.kind", .version = null }, "[]");
    try std.testing.expectError(error.ProjectionIdMismatch, adapter.render(alloc, mismatched));
}

test "TS3-UI-001-002: adapter surface is read-only (no commands or event access)" {
    comptime {
        const fields = std.meta.fields(ui.UiAdapter);
        try std.testing.expectEqual(@as(usize, 1), fields.len);
        try std.testing.expectEqualStrings("projection_id", fields[0].name);

        // No mutating/ingest APIs exist.
        try std.testing.expect(!@hasDecl(ui.UiAdapter, "appendEvent"));
        try std.testing.expect(!@hasDecl(ui.UiAdapter, "issueCommand"));
        try std.testing.expect(!@hasDecl(ui.UiAdapter, "subscribe"));
    }

    // Frame is derived-only: no event/log fields.
    comptime {
        const fi = std.meta.fields(ui.Frame);
        const names = [_][]const u8{ "projection_id", "version", "payload" };
        try std.testing.expectEqual(@as(usize, names.len), fi.len);
        for (fi, names) |f, n| {
            try std.testing.expectEqualStrings(n, f.name);
        }
    }
}

test "TS3-UI-001-003: UI render output is replay-equivalent" {
    const alloc = std.testing.allocator;
    const pid = reg.ProjectionId{ .name = "event.kind", .version = .{ .major = 1, .minor = 0 } };

    const frame_a = frame(pid, "[]");
    const frame_b = frame(pid, "[]");

    var adapter_a = ui.UiAdapter{ .projection_id = pid };
    var out_a = try adapter_a.render(alloc, frame_a);
    defer ui.deinitRenderOutput(alloc, &out_a);

    var adapter_b = ui.UiAdapter{ .projection_id = pid };
    var out_b = try adapter_b.render(alloc, frame_b);
    defer ui.deinitRenderOutput(alloc, &out_b);

    try std.testing.expectEqualStrings(out_a.title, out_b.title);
    try std.testing.expectEqual(out_a.sections.len, out_b.sections.len);
    for (out_a.sections, out_b.sections) |sa, sb| {
        try std.testing.expectEqual(sa.title != null, sb.title != null);
        if (sa.title) |t| try std.testing.expectEqualStrings(t, sb.title.?);
        try std.testing.expectEqual(sa.rows.len, sb.rows.len);
        for (sa.rows, sb.rows) |ra, rb| {
            try std.testing.expectEqualStrings(ra.label, rb.label);
            try std.testing.expectEqualStrings(ra.value, rb.value);
        }
    }
}

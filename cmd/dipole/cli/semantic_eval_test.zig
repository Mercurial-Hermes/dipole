const std = @import("std");
const semantic_eval = @import("semantic_eval");
const proj = @import("projection");
const ev = @import("event");

fn writeLog(tmp_dir: *std.testing.TmpDir, rel: []const u8, lines: []const []const u8) ![]const u8 {
    var file = try tmp_dir.dir.createFile(rel, .{ .truncate = true, .read = true, .mode = 0o644 });
    defer file.close();
    for (lines, 0..) |line, i| {
        if (i != 0) try file.writeAll("\n");
        try file.writeAll(line);
    }
    return try tmp_dir.dir.realpathAlloc(std.testing.allocator, rel);
}

fn projectDirect(alloc: std.mem.Allocator, lines: []const []const u8) ![]const proj.EventKind {
    var events = try alloc.alloc(ev.Event, lines.len);
    defer alloc.free(events);
    for (lines, 0..) |line, i| {
        const cat = std.meta.stringToEnum(ev.Category, line) orelse return error.Invalid;
        events[i] = .{ .category = cat, .event_id = i, .timestamp = null };
    }
    return proj.projectEventKinds(alloc, events);
}

test "TS3-001-003: eval is deterministic and replay-equivalent to direct projection" {
    const alloc = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const log_path = try writeLog(&tmp, "log.txt", &.{
        "session",
        "command",
        "backend",
        "execution",
        "snapshot",
    });
    defer std.testing.allocator.free(log_path);

    const out1 = try semantic_eval.eval(alloc, "event.kind@1.0", log_path);
    defer alloc.free(out1);
    const out2 = try semantic_eval.eval(alloc, "event.kind@1.0", log_path);
    defer alloc.free(out2);

    try std.testing.expectEqualStrings(out1, out2);

    const direct_kinds = try projectDirect(alloc, &.{
        "session",
        "command",
        "backend",
        "execution",
        "snapshot",
    });
    defer alloc.free(direct_kinds);

    var buf = std.ArrayList(u8).init(alloc);
    defer buf.deinit();
    try buf.append('[');
    for (direct_kinds, 0..) |k, i| {
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
    const direct_bytes = buf.items;

    try std.testing.expectEqualStrings(direct_bytes, out1);
}

test "TS3-001-003: eval error contracts" {
    const alloc = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    // Missing log path.
    try std.testing.expectError(error.MissingLogPath, semantic_eval.eval(alloc, "event.kind@1.0", ""));
    const info_missing_log = semantic_eval.errorInfo(error.MissingLogPath).?;
    try std.testing.expectEqualStrings("ERR_MISSING_LOG", info_missing_log.token);
    try std.testing.expectEqual(@as(u8, 2), info_missing_log.exit_code);

    // Invalid selectors.
    try std.testing.expectError(error.MissingVersion, semantic_eval.eval(alloc, "event.kind", "nope"));
    try std.testing.expectError(error.InvalidSelector, semantic_eval.eval(alloc, "@1.0", "nope"));
    try std.testing.expectError(error.InvalidSelector, semantic_eval.eval(alloc, "event.kind@v", "nope"));

    // Unknown version.
    const log_path = try writeLog(&tmp, "log_err.txt", &.{"session"});
    defer std.testing.allocator.free(log_path);
    try std.testing.expectError(error.UnknownVersion, semantic_eval.eval(alloc, "event.kind@9.9", log_path));
}

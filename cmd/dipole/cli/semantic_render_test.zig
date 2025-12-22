const std = @import("std");
const semantic_render = @import("semantic_render");

fn writeLog(tmp_dir: *std.testing.TmpDir, rel: []const u8, lines: []const []const u8) ![]const u8 {
    var file = try tmp_dir.dir.createFile(rel, .{ .truncate = true, .read = true, .mode = 0o644 });
    defer file.close();
    for (lines, 0..) |line, i| {
        if (i != 0) try file.writeAll("\n");
        try file.writeAll(line);
    }
    return try tmp_dir.dir.realpathAlloc(std.testing.allocator, rel);
}

test "semantic render echoes frame payload bytes" {
    const alloc = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const log_path = try writeLog(&tmp, "log.txt", &.{
        "snapshot:[{\"name\":\"x0\",\"value\":\"0x1\"}]",
    });
    defer std.testing.allocator.free(log_path);

    const bytes = try semantic_render.render(alloc, "register.snapshot@1.0", log_path);
    defer alloc.free(bytes);

    try std.testing.expectEqualStrings("[{\"name\":\"x0\",\"value\":\"0x1\"}]", bytes);
}

test "semantic render rejects unknown projection id" {
    const alloc = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const log_path = try writeLog(&tmp, "log.txt", &.{"snapshot:raw"});
    defer std.testing.allocator.free(log_path);

    try std.testing.expectError(error.UnknownProjectionId, semantic_render.render(alloc, "does.not.exist@1.0", log_path));
}

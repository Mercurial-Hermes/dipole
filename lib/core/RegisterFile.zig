const std = @import("std");

pub const RegisterFile = struct {
    /// Create a regfile at a given directory + filename, writing a placeholder.
    /// Returns an owned duplicate of `filename` (caller frees via cleanupAt).
    pub fn initAt(
        alloc: std.mem.Allocator,
        dir: std.fs.Dir,
        filename: []const u8,
    ) ![]u8 {
        var file = try dir.createFile(filename, .{ .truncate = true });
        defer file.close();

        try file.writeAll("(waiting for registers...)\n");

        return try alloc.dupe(u8, filename);
    }

    /// Overwrite file content at `dir/filename`.
    pub fn writeAt(
        dir: std.fs.Dir,
        filename: []const u8,
        content: []const u8,
    ) !void {
        var file = try dir.createFile(filename, .{ .truncate = true });
        defer file.close();

        try file.writeAll(content);
    }

    /// Remove file and free the allocated filename buffer.
    pub fn cleanupAt(
        dir: std.fs.Dir,
        alloc: std.mem.Allocator,
        filename: []u8,
    ) !void {
        _ = dir.deleteFile(filename) catch {};
        alloc.free(filename);
    }

    // ─────────────────────────────────────────────────────────────
    // Production path-based API
    // ─────────────────────────────────────────────────────────────

    /// Initialize a register file at an absolute (or dir-resolvable) path.
    /// Creates/truncates and writes the placeholder. Returns an owned duplicate of `path`.
    pub fn initPath(alloc: std.mem.Allocator, path: []const u8) ![]u8 {
        const last_slash = std.mem.lastIndexOfScalar(u8, path, '/') orelse return error.InvalidPath;
        const dir_path = path[0..last_slash];
        const filename = path[last_slash + 1 ..];

        var dir = try std.fs.openDirAbsolute(dir_path, .{});
        defer dir.close();

        var file = try dir.createFile(filename, .{ .truncate = true });
        defer file.close();

        try file.writeAll("(waiting for registers...)\n");

        return try alloc.dupe(u8, path);
    }

    /// Default production location (MVP).
    pub fn init(alloc: std.mem.Allocator) ![]u8 {
        return try initPath(alloc, "/tmp/dipole_regs.txt");
    }

    /// Overwrite file content at `path`.
    pub fn write(path: []const u8, content: []const u8) !void {
        const last_slash = std.mem.lastIndexOfScalar(u8, path, '/') orelse return error.InvalidPath;
        const dir_path = path[0..last_slash];
        const filename = path[last_slash + 1 ..];

        var dir = try std.fs.openDirAbsolute(dir_path, .{});
        defer dir.close();

        try writeAt(dir, filename, content);
    }

    /// Remove the file at `path` (best-effort) and free the owned `path` buffer.
    pub fn cleanup(alloc: std.mem.Allocator, path: []u8) void {
        const last_slash = std.mem.lastIndexOfScalar(u8, path, '/') orelse {
            alloc.free(path);
            return;
        };

        const dir_path = path[0..last_slash];
        const filename = path[last_slash + 1 ..];

        var dir = std.fs.openDirAbsolute(dir_path, .{}) catch {
            alloc.free(path);
            return;
        };
        defer dir.close();

        _ = dir.deleteFile(filename) catch {};
        alloc.free(path);
    }
};

// ─────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────

test "RegisterFile.initAt writes placeholder content" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const filename = try RegisterFile.initAt(alloc, tmp.dir, "regs.txt");
    defer RegisterFile.cleanupAt(tmp.dir, alloc, filename) catch {};

    const file = try tmp.dir.openFile(filename, .{});
    defer file.close();

    var buf: [256]u8 = undefined;
    const n = try file.read(&buf);

    try std.testing.expectEqualStrings("(waiting for registers...)\n", buf[0..n]);
}

test "RegisterFile.writeAt overwrites content" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const filename = try RegisterFile.initAt(alloc, tmp.dir, "regs.txt");
    defer RegisterFile.cleanupAt(tmp.dir, alloc, filename) catch {};

    const new_content = "REG X0=1 X1=2\n";
    try RegisterFile.writeAt(tmp.dir, filename, new_content);

    const f = try tmp.dir.openFile(filename, .{});
    defer f.close();

    var buf: [256]u8 = undefined;
    const n = try f.read(&buf);

    try std.testing.expectEqualStrings(new_content, buf[0..n]);
}

test "RegisterFile.cleanupAt removes file" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const filename = try RegisterFile.initAt(alloc, tmp.dir, "regs.txt");

    // SAFE copy for checking after cleanup
    const check_name = try alloc.dupe(u8, filename);
    defer alloc.free(check_name);

    try RegisterFile.cleanupAt(tmp.dir, alloc, filename);

    const res = tmp.dir.openFile(check_name, .{}) catch null;
    try std.testing.expect(res == null);
}

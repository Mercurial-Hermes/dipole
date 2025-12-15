const std = @import("std");

pub fn getTerminalWidthOrNull(fd: std.posix.fd_t) ?usize {
    if (!std.posix.isatty(fd)) return null;

    var ws: std.posix.winsize = .{ .row = 0, .col = 0, .xpixel = 0, .ypixel = 0 };
    // NOTE: Zig 0.14 does not expose std.posix.getWinsize on all targets.
    // We intentionally drop to system.ioctl for Darwin/Linux compatibility.
    const rc = std.posix.system.ioctl(fd, std.posix.T.IOCGWINSZ, @intFromPtr(&ws));
    if (std.posix.errno(rc) != .SUCCESS) return null;

    if (ws.col == 0) return null;

    return @intCast(ws.col);
}

pub fn getTerminalHeightOrNull(fd: std.posix.fd_t) ?usize {
    if (!std.posix.isatty(fd)) return null;

    var ws: std.posix.winsize = .{ .row = 0, .col = 0, .xpixel = 0, .ypixel = 0 };
    // NOTE: Zig 0.14 does not expose std.posix.getWinsize on all targets.
    // We intentionally drop to system.ioctl for Darwin/Linux compatibility.
    const rc = std.posix.system.ioctl(fd, std.posix.T.IOCGWINSZ, @intFromPtr(&ws));
    if (std.posix.errno(rc) != .SUCCESS) return null;

    if (ws.row == 0) return null;

    return @intCast(ws.row);
}

test "getTerminalWidthOrNull returns null for non-tty" {
    const f = try std.fs.openFileAbsolute("/dev/null", .{});
    defer f.close();

    try std.testing.expect(getTerminalWidthOrNull(f.handle) == null);
}

test "getTerminalHeightOrNull returns null for non-tty" {
    const f = try std.fs.openFileAbsolute("/dev/null", .{});
    defer f.close();

    try std.testing.expect(getTerminalHeightOrNull(f.handle) == null);
}

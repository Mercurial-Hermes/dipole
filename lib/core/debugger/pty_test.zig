const std = @import("std");
const pty = @import("pty.zig");
const c = @cImport({
    @cInclude("stdlib.h");
    @cInclude("fcntl.h");
    @cInclude("unistd.h");
    @cInclude("sys/ioctl.h");
    @cInclude("spawn.h");
    @cInclude("util.h"); // for posix_openpt on macOS
    @cInclude("errno.h");
});

test "createPtyPair: basic properties" {
    var pair = try pty.createPtyPair();

    // FDs should be non-negative
    try std.testing.expect(pair.master >= 0);
    try std.testing.expect(pair.slave >= 0);
    try std.testing.expect(pair.master != pair.slave);

    // Try writing to master and reading from master (non-blocking read expected)
    // This confirms the fd is valid and writable.
    const msg = "x";
    const written = c.write(pair.master, msg.ptr, msg.len);
    try std.testing.expect(written == msg.len);

    // Non-blocking read: OK to return -1/EAGAIN
    var buf: [16]u8 = undefined;
    const read_bytes = c.read(pair.master, &buf, buf.len);

    // valid results:
    // -1 with errno=EAGAIN or 0 or >0 depending on timing (any is okay)
    if (read_bytes < 0) {
        const errno = std.posix.errno(read_bytes);
        try std.testing.expect(errno == .AGAIN);
    }

    pair.close();
}

test "createPtyPair: CLOEXEC flag is set on master and slave" {
    var pair = try pty.createPtyPair();

    const fdflags_master = try std.posix.fcntl(pair.master, c.F_GETFD, 0);
    const fdflags_slave = try std.posix.fcntl(pair.slave, c.F_GETFD, 0);

    try std.testing.expect((fdflags_master & c.FD_CLOEXEC) != 0);
    try std.testing.expect((fdflags_slave & c.FD_CLOEXEC) != 0);

    pair.close();
}

test "createPtyPair: master must be non-blocking" {
    var pair = try pty.createPtyPair();

    const flags = try std.posix.fcntl(pair.master, c.F_GETFL, 0);
    try std.testing.expect((flags & c.O_NONBLOCK) != 0);

    pair.close();
}

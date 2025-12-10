const std = @import("std");
const c = @cImport({
    @cInclude("stdlib.h");
    @cInclude("fcntl.h");
    @cInclude("unistd.h");
    @cInclude("sys/ioctl.h");
    @cInclude("spawn.h");
    @cInclude("util.h"); // for posix_openpt on macOS
    @cInclude("errno.h");
});

pub const PtyPair = struct {
    master: c_int,
    slave: c_int,

    pub fn close(self: *PtyPair) void {
        // close master first or slave first — order does not matter
        _ = std.posix.close(self.master);
        _ = std.posix.close(self.slave);
    }
};

pub const PtyError = error{
    OpenPtyFailed,
    GrantFailed,
    UnlockFailed,
    PtsnameFailed,
    OpenSlaveFailed,
    SetMasterFlagsFailed,
    SetSlaveFlagsFailed,
};

pub fn createPtyPair() !PtyPair {
    // --- 1. Create PTY master ---
    const master = c.posix_openpt(c.O_RDWR | c.O_NOCTTY);
    if (master < 0) return PtyError.OpenPtyFailed;

    if (c.grantpt(master) != 0) return PtyError.GrantFailed;
    if (c.unlockpt(master) != 0) return PtyError.UnlockFailed;

    // --- 2. Slave name ---
    const slave_name = c.ptsname(master) orelse return PtyError.PtsnameFailed;

    // --- 3. Open slave PTY ---
    const slave = c.open(slave_name, c.O_RDWR | c.O_NOCTTY, @as(c.mode_t, 0));
    if (slave < 0) return PtyError.OpenSlaveFailed;

    // Ensure CLOEXEC to avoid leaking fds into child
    if (c.fcntl(master, c.F_SETFD, c.FD_CLOEXEC) != 0) return PtyError.SetMasterFlagsFailed;
    if (c.fcntl(slave, c.F_SETFD, c.FD_CLOEXEC) != 0) return PtyError.SetSlaveFlagsFailed;

    // Optional: make master non-blocking (recommended)
    const flags = c.fcntl(master, c.F_GETFL, @as(c_int, 0));
    _ = c.fcntl(master, c.F_SETFL, flags | c.O_NONBLOCK);

    return PtyPair{ .master = master, .slave = slave };
}

test "createPtyPair: basic properties" {
    var pair = try createPtyPair();

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
    var pair = try createPtyPair();

    const fdflags_master = try std.posix.fcntl(pair.master, c.F_GETFD, 0);
    const fdflags_slave = try std.posix.fcntl(pair.slave, c.F_GETFD, 0);

    try std.testing.expect((fdflags_master & c.FD_CLOEXEC) != 0);
    try std.testing.expect((fdflags_slave & c.FD_CLOEXEC) != 0);

    pair.close();
}

test "createPtyPair: master must be non-blocking" {
    var pair = try createPtyPair();

    const flags = try std.posix.fcntl(pair.master, c.F_GETFL, 0);
    try std.testing.expect((flags & c.O_NONBLOCK) != 0);

    pair.close();
}

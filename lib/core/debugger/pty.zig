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

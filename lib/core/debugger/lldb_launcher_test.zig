const std = @import("std");
const launcher = @import("lldb_launcher.zig");

test "attach(0): attach spawns lldb for target pid" {
    // Launch LLDB with no target to verify process + PTY wiring.
    var ll = try launcher.LLDBLauncher.attach(0);
    defer ll.shutdown() catch {};

    // Ensure we got a valid LLDB pid.
    try std.testing.expect(ll.lldb_pid > 0);

    // Ensure master_fd is valid and readable (non-blocking).
    try std.testing.expect(ll.master_fd >= 0);

    // Try a non-blocking read to confirm the PTY is alive.
    // Best-effort liveness probe; read may return EAGAIN.
    var tmp: [64]u8 = undefined;
    _ = std.posix.read(ll.master_fd, &tmp) catch {};

    // Interrupt (sends ETX) to ensure write path works.
    if (ll.master_fd >= 0) try ll.interrupt();
}

test "attach spawns lldb for target pid" {
    // Use our own pid as the target to ensure -p <pid> path runs.
    const self_pid: i32 = @intCast(std.c.getpid());

    var ll = try launcher.LLDBLauncher.attach(self_pid);
    defer ll.shutdown() catch {};

    try std.testing.expect(ll.lldb_pid > 0);
    try std.testing.expect(ll.master_fd >= 0);

    // Try a non-blocking read to confirm the PTY is alive.
    // Best-effort liveness probe; read may return EAGAIN.
    var tmp: [64]u8 = undefined;
    _ = std.posix.read(ll.master_fd, &tmp) catch {};

    // Send interrupt to ensure write path works.
    if (ll.master_fd >= 0) try ll.interrupt();
}

test "lldb launcher: shutdown terminates lldb" {
    var ll = try launcher.LLDBLauncher.attach(0);

    try std.testing.expect(ll.lldb_pid > 0);

    // shutdown should reap the child; it must not error.
    try ll.shutdown();

    // A second isAlive should report not running.
    const alive = try ll.isAlive();
    try std.testing.expect(!alive);
}

const std = @import("std");
const c = @cImport({
    @cInclude("stdlib.h");
    @cInclude("fcntl.h");
    @cInclude("unistd.h");
    @cInclude("sys/ioctl.h");
    @cInclude("spawn.h");
    @cInclude("util.h"); // for posix_openpt on macOS
});

pub fn main() !void {
    const gpa = std.heap.page_allocator;

    // --- 1. Create PTY master ---
    const master = c.posix_openpt(c.O_RDWR | c.O_NOCTTY);
    if (master < 0) return error.OpenPtyFailed;

    if (c.grantpt(master) != 0) return error.GrantFailed;
    if (c.unlockpt(master) != 0) return error.UnlockFailed;

    // --- 2. Slave name ---
    const slave_name_ptr = c.ptsname(master) orelse return error.PtsnameFailed;

    // --- 3. Open slave PTY ---
    const slave = c.open(slave_name_ptr, c.O_RDWR | c.O_NOCTTY, @as(c.mode_t, 0));
    if (slave < 0) return error.OpenSlaveFailed;

    // --- 4. posix_spawn file actions ---
    var actions: c.posix_spawn_file_actions_t = undefined;
    if (c.posix_spawn_file_actions_init(&actions) != 0) return error.SpawnInitFailed;

    // Redirect all stdio to slave PTY
    if (c.posix_spawn_file_actions_adddup2(&actions, slave, c.STDIN_FILENO) != 0) return error.Dup2Failed;
    if (c.posix_spawn_file_actions_adddup2(&actions, slave, c.STDOUT_FILENO) != 0) return error.Dup2Failed;
    if (c.posix_spawn_file_actions_adddup2(&actions, slave, c.STDERR_FILENO) != 0) return error.Dup2Failed;

    var pid: c.pid_t = 0;

    // argv needs a null terminator; string literal is const, so we constCast when passing to C
    const argv = [_:null][*c]const u8{
        "lldb",
    };
    const envp = std.os.environ;

    // --- 5. Spawn LLDB ---
    const spawn_err = c.posix_spawnp(
        &pid,
        argv[0], // program name
        &actions,
        null,
        @as([*c]const [*c]u8, @ptrCast(@constCast(argv[0..].ptr))),
        @as([*c]const [*c]u8, @ptrCast(envp.ptr)),
    );

    if (spawn_err != 0) {
        std.debug.print("posix_spawn failed: {}\n", .{spawn_err});
        return error.SpawnFailed;
    }

    std.debug.print("Spawned lldb with pid={}\n", .{pid});

    // --- 6. Non-blocking master for reading ---
    const flags = try std.posix.fcntl(master, std.posix.F.GETFL, 0);
    _ = try std.posix.fcntl(master, std.posix.F.SETFL, flags | c.O_NONBLOCK);

    var output = std.ArrayList(u8).init(gpa);
    defer output.deinit();

    // --- 7. Wait for prompt ---
    try readUntilPrompt(master, &output);
    std.debug.print("LLDB banner:\n{s}\n", .{output.items});

    // --- 8. Send a command ---
    _ = try std.posix.write(master, "help\n");

    output.clearRetainingCapacity();
    try readUntilPrompt(master, &output);
    std.debug.print("Help output:\n{s}\n", .{output.items});
}

fn readUntilPrompt(fd: std.posix.fd_t, out: *std.ArrayList(u8)) !void {
    const prompt = "(lldb) ";
    var buf: [1024]u8 = undefined;

    while (true) {
        const n = std.posix.read(fd, &buf) catch |err| switch (err) {
            error.WouldBlock => {
                std.time.sleep(10_000_000);
                continue;
            },
            else => return err,
        };
        if (n == 0) return;
        try out.appendSlice(buf[0..n]);
        if (std.mem.endsWith(u8, out.items, prompt)) return;
    }
}

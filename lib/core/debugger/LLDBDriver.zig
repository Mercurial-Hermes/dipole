const std = @import("std");
const pty = @import("./pty.zig");

const c = @cImport({
    @cInclude("stdlib.h");
    @cInclude("fcntl.h");
    @cInclude("unistd.h");
    @cInclude("sys/ioctl.h");
    @cInclude("spawn.h");
    @cInclude("util.h"); // macOS: posix_openpt lives here
    @cInclude("errno.h");
});

const DebugLLDB = false; // set true when debugging dipole backend

pub const LLDBDriver = struct {
    allocator: std.mem.Allocator,
    lldb_pid: c.pid_t,
    target_pid: c.pid_t,
    master_fd: std.posix.fd_t,
    buffer: std.ArrayList(u8),

    pub const DriverError = error{
        SpawnInitFailed,
        Dup2Failed,
        SpawnFailed,
        PromptTimeout,
        ReadFailed,
        WriteFailed,
        ChildExitedEarly,
    };

    pub const PromptMode = enum {
        /// Stop reading after seeing "(lldb) " prompt.
        LldbPrompt,
        /// Stop when child produces no data for a short timeout.
        BestEffortChunk,
    };

    /// Attach to an existing process by pid.
    pub fn initAttach(
        allocator: std.mem.Allocator,
        target_pid: i32,
    ) !LLDBDriver {
        var pty_pair = try pty.createPtyPair();
        errdefer {
            _ = pty_pair.close();
        }

        var actions: c.posix_spawn_file_actions_t = undefined;
        if (c.posix_spawn_file_actions_init(&actions) != 0) return DriverError.SpawnInitFailed;

        if (c.posix_spawn_file_actions_adddup2(&actions, pty_pair.slave, c.STDIN_FILENO) != 0) return DriverError.Dup2Failed;
        if (c.posix_spawn_file_actions_adddup2(&actions, pty_pair.slave, c.STDOUT_FILENO) != 0) return DriverError.Dup2Failed;
        if (c.posix_spawn_file_actions_adddup2(&actions, pty_pair.slave, c.STDERR_FILENO) != 0) return DriverError.Dup2Failed;

        var lldb_pid: c.pid_t = 0;

        // argv needs a null terminator; string literal is const, so we constCast when passing to C
        const argv = [_:null][*c]const u8{
            "lldb",
        };
        const envp = std.os.environ;

        const spawn_err = c.posix_spawnp(
            &lldb_pid,
            argv[0],
            &actions,
            null,
            @as([*c]const [*c]u8, @ptrCast(@constCast(argv[0..].ptr))),
            @as([*c]const [*c]u8, @ptrCast(envp.ptr)),
        );

        if (spawn_err != 0) {
            return DriverError.SpawnFailed;
        }

        if (DebugLLDB) {
            std.debug.print("Spawned LLDB with pid={}\n", .{lldb_pid});
        }

        _ = c.posix_spawn_file_actions_destroy(&actions);
        _ = std.posix.close(pty_pair.slave);

        const buf = std.ArrayList(u8).init(allocator);

        return LLDBDriver{
            .allocator = allocator,
            .lldb_pid = lldb_pid,
            .target_pid = @intCast(target_pid),
            .master_fd = pty_pair.master,
            .buffer = buf,
        };
    }

    /// Launch a new process under lldb.
    pub fn initLaunch(
        allocator: std.mem.Allocator,
        exe_path: []const u8,
        args: []const []const u8,
    ) !LLDBDriver {
        var pty_pair = try pty.createPtyPair();
        errdefer _ = pty_pair.close();

        var actions: c.posix_spawn_file_actions_t = undefined;
        if (c.posix_spawn_file_actions_init(&actions) != 0)
            return DriverError.SpawnInitFailed;

        // Route LLDB's stdio to the slave PTY.
        if (c.posix_spawn_file_actions_adddup2(&actions, pty_pair.slave, c.STDIN_FILENO) != 0)
            return DriverError.Dup2Failed;
        if (c.posix_spawn_file_actions_adddup2(&actions, pty_pair.slave, c.STDOUT_FILENO) != 0)
            return DriverError.Dup2Failed;
        if (c.posix_spawn_file_actions_adddup2(&actions, pty_pair.slave, c.STDERR_FILENO) != 0)
            return DriverError.Dup2Failed;

        // Build argv for LLDB: ["lldb", "--", exe_path, args..., null]
        var argv_builder = std.ArrayList([*c]const u8).init(allocator);
        defer argv_builder.deinit();

        try argv_builder.append("lldb");
        try argv_builder.append("--");
        try argv_builder.append(@ptrCast(exe_path));

        for (args) |a| {
            try argv_builder.append(@ptrCast(a));
        }

        // Append null terminator for C
        try argv_builder.append(null);

        var child_pid: c.pid_t = 0;
        const envp = std.os.environ;

        const spawn_err = c.posix_spawnp(
            &child_pid,
            argv_builder.items[0],
            &actions,
            null,
            @ptrCast(argv_builder.items.ptr), // C argv**
            @ptrCast(envp.ptr),
        );
        if (spawn_err != 0)
            return DriverError.SpawnFailed;

        // Clean up
        _ = std.posix.close(pty_pair.slave);
        _ = c.posix_spawn_file_actions_destroy(&actions);

        const buffer = std.ArrayList(u8).init(allocator);

        return LLDBDriver{
            .allocator = allocator,
            .lldb_pid = child_pid,
            .target_pid = -1, // Unknown until we parse LLDB output; left for future work
            .master_fd = pty_pair.master,
            .buffer = buffer,
        };
    }

    pub fn deinit(self: *LLDBDriver) void {
        // Free buffer memory
        self.buffer.deinit();

        // Invalidate members — defensive programming
        self.master_fd = -1;
        self.lldb_pid = -1;
        self.target_pid = -1;

        // Reset buffer to an empty, safely usable state
        self.buffer = std.ArrayList(u8).init(self.allocator);
    }

    /// Wait for the initial "(lldb) " prompt after starting.
    pub fn waitForPrompt(self: *LLDBDriver) ![]const u8 {
        const prompt = "(lldb) ";
        self.buffer.clearRetainingCapacity();

        var tmp: [1024]u8 = undefined;

        // timeout after ~3 seconds of no output
        var consecutive_would_block: u32 = 0;
        const max_wait_iters: u32 = 300; // 300 * 10ms = 3 seconds

        while (true) {
            const n = std.posix.read(self.master_fd, &tmp) catch |err| switch (err) {
                error.WouldBlock => {
                    consecutive_would_block += 1;
                    if (consecutive_would_block >= max_wait_iters) {
                        return DriverError.PromptTimeout;
                    }
                    std.time.sleep(10_000_000); // 10 ms
                    continue;
                },
                else => return DriverError.ReadFailed,
            };

            // Reset timeout counter on successful read
            consecutive_would_block = 0;

            if (n == 0) {
                // EOF from LLDB - it probably exited early
                return DriverError.ChildExitedEarly;
            }

            try self.buffer.appendSlice(tmp[0..n]);

            if (std.mem.endsWith(u8, self.buffer.items, prompt)) {
                return self.buffer.items;
            }
        }
    }

    /// Send a single command line to LLDB (without trailing newline).
    pub fn sendLine(self: *LLDBDriver, line: []const u8) !void {
        // Construct "line\n"
        var buf = std.ArrayList(u8).init(self.allocator);
        defer buf.deinit();
        try buf.appendSlice(line);
        try buf.append('\n');

        const data = buf.items;

        var total_written: usize = 0;
        while (total_written < data.len) {
            const n = std.posix.write(self.master_fd, data[total_written..]) catch {
                return DriverError.WriteFailed;
            };

            if (n == 0) {
                return DriverError.WriteFailed;
            }

            total_written += n;
        }
    }

    /// Read all available output until we hit the prompt (or timeout).
    pub fn readUntilPrompt(
        self: *LLDBDriver,
        mode: PromptMode,
    ) ![]const u8 {
        // For now, both modes use the same logic.
        // Later, BestEffortChunk will have a different implementation.
        _ = mode;
        return try self.waitForPrompt();
    }

    /// Politely tell lldb to quit and reap the child.
    pub fn shutdown(self: *LLDBDriver) !void {
        if (self.master_fd == -1) return;

        const quit_cmd = "quit\n";
        _ = std.posix.write(self.master_fd, quit_cmd) catch {};

        _ = std.posix.close(self.master_fd);

        self.master_fd = -1;

        _ = std.posix.waitpid(self.lldb_pid, 0);

        self.lldb_pid = -1;
    }

    /// Check if LLDB has exited (non-blocking where possible).
    pub fn isAlive(self: *LLDBDriver) !bool {
        if (self.lldb_pid <= 0) return false;

        const result = std.posix.waitpid(self.lldb_pid, std.posix.W.NOHANG);

        // If result.pid == 0 → child is still running
        // If result.pid == self.lldb_pid → child exited
        return result.pid == 0;
    }
};

test "LLDBDriver: initAttach spawns lldb and returns driver" {
    const allocator = std.testing.allocator;

    const driver = try LLDBDriver.initAttach(allocator, 0); // target_pid=0 not used yet
    defer {
        // We will add driver.shutdown() later, but for now close FD to avoid leaks.
        _ = std.posix.close(driver.master_fd);
        driver.buffer.deinit();
    }

    try std.testing.expect(driver.lldb_pid > 0);
    try std.testing.expect(driver.master_fd >= 0);
}

test "LLDBDriver: initLaunch starts lldb and launches the program" {
    const allocator = std.testing.allocator;

    // We need a simple program to launch.
    // macOS always has /usr/bin/true — guaranteed to exist and exit immediately.
    const exe_path = "/usr/bin/true";

    var driver = try LLDBDriver.initLaunch(allocator, exe_path, &.{});
    defer driver.buffer.deinit();

    // LLDB should produce the startup banner
    const banner = try driver.waitForPrompt();
    try std.testing.expect(std.mem.containsAtLeast(u8, banner, 1, "(lldb)"));

    // LLDB should be alive initially
    try std.testing.expect(try driver.isAlive());

    // Now shut it down
    try driver.shutdown();

    try std.testing.expect(!(try driver.isAlive()));
}

test "LLDBDriver: waitForPrompt reads initial (lldb) banner" {
    const allocator = std.testing.allocator;

    var driver = try LLDBDriver.initAttach(allocator, 0);
    defer {
        _ = std.posix.close(driver.master_fd);
        driver.buffer.deinit();
    }

    const banner = try driver.waitForPrompt();

    // LLDB always prints some diagnostic text + "(lldb) "
    try std.testing.expect(std.mem.containsAtLeast(u8, banner, 1, "(lldb)"));
}

test "LLDBDriver: shutdown cleanly terminates lldb and closes master fd" {
    const allocator = std.testing.allocator;

    // 1. Create driver
    var driver = try LLDBDriver.initAttach(allocator, 0);
    defer driver.buffer.deinit();

    // 2. Wait for the initial prompt (ensures LLDB is alive)
    _ = try driver.waitForPrompt();

    // 3. Call shutdown — this is the function under test.
    try driver.shutdown();

    // 4. After shutdown, master_fd should be closed.
    // Reading from a closed fd should return EBADF.
    var buf: [8]u8 = undefined;
    _ = std.posix.read(driver.master_fd, &buf) catch |err| {
        try std.testing.expect(err == error.NotOpenForReading);
        return;
    };

    // If read somehow succeeded, that's incorrect.
    try std.testing.expect(false);
}

test "LLDBDriver: sendLine sends command and waitForPrompt returns new output" {
    const allocator = std.testing.allocator;

    var driver = try LLDBDriver.initAttach(allocator, 0);
    defer driver.buffer.deinit();

    // Wait for initial banner
    _ = try driver.waitForPrompt();

    // Send a simple LLDB command
    try driver.sendLine("help");

    const output = try driver.waitForPrompt();

    // 'help' ALWAYS prints at least one line containing "Debugger commands"
    try std.testing.expect(std.mem.containsAtLeast(u8, output, 1, "Debugger commands"));

    try driver.shutdown();
}

test "LLDBDriver: readUntilPrompt returns full command output" {
    const allocator = std.testing.allocator;

    var driver = try LLDBDriver.initAttach(allocator, 0);
    defer driver.buffer.deinit();

    // Sync with the initial LLDB prompt.
    _ = try driver.waitForPrompt();

    // Send a command.
    try driver.sendLine("help");

    // Now use readUntilPrompt() instead of waitForPrompt().
    const output = try driver.readUntilPrompt(.LldbPrompt);

    // LLDB help output must contain this phrase:
    try std.testing.expect(std.mem.containsAtLeast(u8, output, 1, "Debugger commands"));

    try driver.shutdown();
}

test "LLDBDriver: isAlive true before shutdown and false after" {
    const allocator = std.testing.allocator;

    var driver = try LLDBDriver.initAttach(allocator, 0);
    defer driver.buffer.deinit();

    // Sync with LLDB startup
    _ = try driver.waitForPrompt();

    // LLDB should be alive immediately after spawn
    try std.testing.expect(try driver.isAlive());

    // Shut down LLDB
    try driver.shutdown();

    // Now LLDB should no longer be alive
    try std.testing.expect(!(try driver.isAlive()));
}

test "LLDBDriver: deinit frees buffer and leaves struct inert" {
    const allocator = std.testing.allocator;

    var driver = try LLDBDriver.initAttach(allocator, 0);

    // Let LLDB fully start
    _ = try driver.waitForPrompt();

    // Shutdown first (deinit must not touch process or FDs)
    try driver.shutdown();

    // Capture pointer for testing (must not crash when deinit frees it)
    const old_items_ptr = driver.buffer.items.ptr;

    // Now deinit the driver
    driver.deinit();

    // After deinit, buffer memory must be freed:
    // accessing items.len must be legal (ArrayList resets safely)
    try std.testing.expect(driver.buffer.items.len == 0);

    // The pointer *must* have changed or become null:
    // i.e. the memory was deallocated.
    try std.testing.expect(driver.buffer.items.ptr != old_items_ptr);
}

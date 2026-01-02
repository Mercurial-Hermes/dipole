const std = @import("std");
const pty = @import("pty.zig");

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

pub const LLDBLauncher = struct {
    lldb_pid: c.pid_t,
    master_fd: std.posix.fd_t,

    pub const LaunchError = error{
        SpawnInitFailed,
        Dup2Failed,
        SpawnFailed,
    };

    /// Attach to an existing process by pid.
    pub fn attach(
        target_pid: i32,
    ) !LLDBLauncher {
        var pty_pair = try pty.createPtyPair();
        errdefer {
            _ = pty_pair.close();
        }

        var actions: c.posix_spawn_file_actions_t = undefined;
        if (c.posix_spawn_file_actions_init(&actions) != 0) return LaunchError.SpawnInitFailed;

        if (c.posix_spawn_file_actions_adddup2(&actions, pty_pair.slave, c.STDIN_FILENO) != 0) return LaunchError.Dup2Failed;
        if (c.posix_spawn_file_actions_adddup2(&actions, pty_pair.slave, c.STDOUT_FILENO) != 0) return LaunchError.Dup2Failed;
        if (c.posix_spawn_file_actions_adddup2(&actions, pty_pair.slave, c.STDERR_FILENO) != 0) return LaunchError.Dup2Failed;

        var lldb_pid: c.pid_t = 0;

        var pid_buf: [32:0]u8 = undefined;
        const pid_str = try std.fmt.bufPrintZ(&pid_buf, "{d}", .{target_pid});

        const argv = [_:null][*c]const u8{
            "lldb",
            "-p",
            pid_str.ptr,
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
            return LaunchError.SpawnFailed;
        }

        if (DebugLLDB) {
            std.debug.print("Spawned LLDB with pid={}\n", .{lldb_pid});
        }

        // Clean up
        _ = c.posix_spawn_file_actions_destroy(&actions);
        _ = std.posix.close(pty_pair.slave);

        return LLDBLauncher{
            .lldb_pid = lldb_pid,
            .master_fd = pty_pair.master,
        };
    }

    /// Launch a new process under lldb.
    pub fn launch(
        allocator: std.mem.Allocator,
        exe_path: []const u8,
        args: []const []const u8,
    ) !LLDBLauncher {
        var pty_pair = try pty.createPtyPair();
        errdefer _ = pty_pair.close();

        var actions: c.posix_spawn_file_actions_t = undefined;
        if (c.posix_spawn_file_actions_init(&actions) != 0)
            return LaunchError.SpawnInitFailed;

        // Route LLDB's stdio to the slave PTY.
        if (c.posix_spawn_file_actions_adddup2(&actions, pty_pair.slave, c.STDIN_FILENO) != 0)
            return LaunchError.Dup2Failed;
        if (c.posix_spawn_file_actions_adddup2(&actions, pty_pair.slave, c.STDOUT_FILENO) != 0)
            return LaunchError.Dup2Failed;
        if (c.posix_spawn_file_actions_adddup2(&actions, pty_pair.slave, c.STDERR_FILENO) != 0)
            return LaunchError.Dup2Failed;

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
            return LaunchError.SpawnFailed;

        // Clean up
        _ = c.posix_spawn_file_actions_destroy(&actions);
        _ = std.posix.close(pty_pair.slave);

        return LLDBLauncher{
            .lldb_pid = child_pid,
            .master_fd = pty_pair.master,
        };
    }

    /// Politely tell lldb to quit and reap the child.
    pub fn shutdown(self: *LLDBLauncher) !void {
        if (self.master_fd == -1) return;

        _ = std.posix.close(self.master_fd);

        self.master_fd = -1;

        _ = std.posix.waitpid(self.lldb_pid, 0);

        self.lldb_pid = -1;
    }

    /// Check if LLDB has exited (non-blocking where possible).
    pub fn isAlive(self: *LLDBLauncher) !bool {
        if (self.lldb_pid <= 0) return false;

        const result = std.posix.waitpid(self.lldb_pid, std.posix.W.NOHANG);

        // If result.pid == 0 → child is still running
        // If result.pid == self.lldb_pid → child exited
        return result.pid == 0;
    }

    pub fn interrupt(self: *LLDBLauncher) !void {
        // macOS LLDB receives ^C via writing ASCII ETX (0x03) to stdin
        const sig = "\x03";
        _ = try std.posix.write(self.master_fd, sig);
    }
};

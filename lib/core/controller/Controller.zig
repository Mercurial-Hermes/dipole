const std = @import("std");
const LLDBDriver = @import("lldbdriver").LLDBDriver;
const Log = @import("log");

// NOTE: Controller, not LLDBDriver, owns lifecycle policy.
// Driver may detect exit, but Controller decides what it means.
pub const SessionState = union(enum) {
    Stopped,
    Running,
    Exited: struct { code: ?u8 = null },
};

pub const Controller = struct {
    alloc: std.mem.Allocator,
    driver: *LLDBDriver,

    session_state: SessionState = .Stopped,

    /// Cheap serialization guard for Exp 1.1.
    /// Later becomes a mutex + queue when you add IPC/tmux clients.
    in_flight: bool = false,

    pub const Error = error{
        SessionExited,
        Busy,
    };

    pub fn init(alloc: std.mem.Allocator, driver: *LLDBDriver) Controller {
        return .{ .alloc = alloc, .driver = driver };
    }

    pub fn state(self: *const Controller) SessionState {
        return self.session_state;
    }

    /// Execute a raw LLDB command line (without trailing newline).
    /// Returns owned output (caller frees).
    pub fn execRaw(self: *Controller, cmd: []const u8) ![]u8 {
        if (self.session_state == .Exited) return Error.SessionExited;
        if (self.in_flight) return Error.Busy;

        self.in_flight = true;
        defer self.in_flight = false;

        // For Exp 1.1, execRaw is defined as sendLine + readUntilPrompt.
        try self.driver.sendLine(cmd);
        const out_borrowed = try self.driver.readUntilPrompt(.LldbPrompt);

        // Update controller session state.
        // We treat driver's Exited detection as a strong signal, but also fall back to parsing output.
        if (self.driver.state == .Exited or outputIndicatesExit(out_borrowed)) {
            self.session_state = .{ .Exited = .{ .code = parseExitCode(out_borrowed) } };
        } else {
            // Minimal policy for now: after a prompt, we’re stopped.
            // (Running state will matter more once we introduce async stop events + brokered clients.)
            self.session_state = .Stopped;
        }

        return try self.alloc.dupe(u8, out_borrowed);
    }

    fn outputIndicatesExit(out: []const u8) bool {
        // Mirror the driver heuristic, but keep it private to Controller for now.
        const has_status = std.mem.containsAtLeast(u8, out, 1, "exited with status");
        const has_normal = std.mem.containsAtLeast(u8, out, 1, "exited normally");
        const has_process = std.mem.containsAtLeast(u8, out, 1, "Process");
        const has_exited = std.mem.containsAtLeast(u8, out, 1, "exited");
        return has_status or has_normal or (has_process and has_exited);
    }

    fn parseExitCode(out: []const u8) ?u8 {
        // Look for: "exited with status = 0 (..."
        const needle = "exited with status =";
        const i = std.mem.indexOf(u8, out, needle) orelse return null;

        var s = out[i + needle.len ..];
        while (s.len != 0 and s[0] == ' ') s = s[1..];

        var n: usize = 0;
        while (n < s.len and std.ascii.isDigit(s[n])) : (n += 1) {}
        if (n == 0) return null;

        const v = std.fmt.parseInt(u16, s[0..n], 10) catch return null;
        if (v > 255) return null;
        return @intCast(v);
    }
};

test "Controller: detects inferior exit and transitions to Exited" {
    const alloc = std.testing.allocator;

    // Use your own deterministic target if you want:
    // const exe = "/path/to/zig-out/bin/exit_0_c";
    // But /usr/bin/true is stable and already used in your LLDBDriver tests.
    var driver = try LLDBDriver.initLaunch(alloc, "/usr/bin/true", &.{});
    defer driver.buffer.deinit();

    _ = try driver.waitForPrompt();

    var ctl = Controller.init(alloc, &driver);

    const out = try ctl.execRaw("run");
    defer alloc.free(out);

    switch (ctl.state()) {
        .Exited => |e| {
            // exit code parse may be null depending on what was captured, but state must be Exited.
            if (e.code) |c| try std.testing.expectEqual(@as(u8, 0), c);
        },
        else => try std.testing.expect(false),
    }

    try driver.shutdown();
}

test "Controller: refuses commands after exit" {
    const alloc = std.testing.allocator;

    var driver = try LLDBDriver.initLaunch(alloc, "/usr/bin/true", &.{});
    defer driver.buffer.deinit();

    _ = try driver.waitForPrompt();

    var ctl = Controller.init(alloc, &driver);

    const out = try ctl.execRaw("run");
    defer alloc.free(out);

    try std.testing.expectError(Controller.Error.SessionExited, ctl.execRaw("help"));

    try driver.shutdown();
}

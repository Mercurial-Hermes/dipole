const std = @import("std");
const builtin = @import("builtin");
const Log = @import("log");

pub const Tmux = struct {
    pub const Command = []const []const u8;

    /// Prevents bootstrap recursion (dipole runs inside tmux, which would otherwise try to bootstrap again).
    pub const sentinel_bootstrapped = "DIPOLE_TMUX_BOOTSTRAPPED";

    /// Exposed so dipole can know which tmux session it belongs to (optional, but useful for debugging/UX).
    pub const env_session = "DIPOLE_TMUX_SESSION";

    /// Exposed so dipole can write register snapshots to a stable location known at bootstrap time.
    pub const env_reg_path = "DIPOLE_REG_PATH";

    pub fn alreadyBootstrapped() bool {
        // Use libc getenv to avoid std.process API drift across Zig versions.
        return cGetEnvExists(sentinel_bootstrapped);
    }

    pub fn isInsideAnyTmux() bool {
        return cGetEnvExists("TMUX");
    }

    pub fn isAvailable(alloc: std.mem.Allocator) bool {
        var child = std.process.Child.init(&.{ "tmux", "-V" }, alloc);
        child.stdin_behavior = .Ignore;
        child.stdout_behavior = .Ignore;
        child.stderr_behavior = .Inherit; //for debugging

        const res = child.spawnAndWait() catch return false;
        return switch (res) {
            .Exited => |code| code == 0,
            else => false,
        };
    }

    /// Generate a unique session name for this dipole invocation using dipole's PID.
    pub fn defaultSessionName(alloc: std.mem.Allocator) ![]const u8 {
        const pid: i32 = @intCast(std.c.getpid());
        return std.fmt.allocPrint(alloc, "dipole-{d}", .{pid});
    }

    /// Generate a stable reg snapshot path for this dipole invocation using the session name.
    pub fn defaultRegPath(alloc: std.mem.Allocator, session_name: []const u8) ![]const u8 {
        return std.fmt.allocPrint(alloc, "/tmp/dipole_regs_{s}.txt", .{session_name});
    }

    /// Returns the register snapshot path to use *for this dipole invocation*.
    ///
    /// - If running inside a bootstrapped tmux session, the wrapper exports DIPOLE_REG_PATH.
    /// - Otherwise, fall back to a deterministic path derived from dipole's PID.
    ///
    /// Returned slice is owned by caller.
    pub fn currentRegPathOwned(alloc: std.mem.Allocator) ![]const u8 {
        if (cGetEnvDupOwned(alloc, env_reg_path)) |p| {
            return p;
        } else {
            const session_name = try defaultSessionName(alloc);
            defer alloc.free(session_name);
            return try defaultRegPath(alloc, session_name);
        }
    }

    /// Creates/overwrites the reg file with a placeholder so `tail -f` has something immediately.
    pub fn initRegFile(reg_path: []const u8) void {
        const f = std.fs.createFileAbsolute(reg_path, .{ .truncate = true }) catch return;
        defer f.close();
        _ = f.write("(waiting for registers...)\n") catch {};
    }

    /// Builds the tmux "pane 0" command.
    ///
    /// IMPORTANT: We do *not* rely on dipole to clean up the tmux session, because dipole may crash.
    /// Instead, we run dipole under a small `bash -lc` wrapper that traps EXIT and kills the session.
    fn buildWrappedDipoleCommandString(
        alloc: std.mem.Allocator,
        session_name: []const u8,
        reg_path: []const u8,
        dipole_path: []const u8,
        subcommand: []const u8,
        target: []const u8,
        extra_args: []const []const u8,
    ) ![]const u8 {
        const dipole_cmd = try buildDipoleCommandString(alloc, dipole_path, subcommand, target, extra_args);
        errdefer alloc.free(dipole_cmd);

        const script = try std.fmt.allocPrint(
            alloc,
            \\export {s}=1;
            \\export {s}="{s}";
            \\export {s}="{s}";
            \\cleanup() {{
            \\  rm -f "{s}" 2>/dev/null || true;
            \\  tmux kill-session -t "{s}" 2>/dev/null || true;
            \\}}
            \\trap cleanup EXIT INT TERM HUP;
            \\{s}
        ,
            .{
                sentinel_bootstrapped, // {s}
                env_session, // {s}
                session_name, // {s}
                env_reg_path, // {s}
                reg_path, // {s}
                reg_path, // {s}  <-- rm target
                session_name, // {s}  <-- kill-session target
                dipole_cmd, // {s}
            },
        );
        errdefer alloc.free(script);

        const wrapped = try std.fmt.allocPrint(alloc, "bash -lc '{s}'", .{script});

        alloc.free(dipole_cmd);
        alloc.free(script);
        return wrapped;
    }

    pub fn planBootstrap(
        alloc: std.mem.Allocator,
        session_name: []const u8,
        dipole_path: []const u8,
        subcommand: []const u8,
        target: []const u8,
        extra_args: []const []const u8,
        reg_path: []const u8,
        inside_tmux: bool,
    ) ![][][]const u8 {
        const run_cmd = try buildWrappedDipoleCommandString(
            alloc,
            session_name,
            reg_path,
            dipole_path,
            subcommand,
            target,
            extra_args,
        );
        errdefer alloc.free(run_cmd);

        const regsview_path = try std.fmt.allocPrint(alloc, "{s}-regsview", .{dipole_path});
        errdefer alloc.free(regsview_path);

        const regs_cmd = try std.fmt.allocPrint(
            alloc,
            "bash -lc '\"{s}\" --path \"{s}\"'",
            .{ regsview_path, reg_path },
        );
        errdefer alloc.free(regs_cmd);

        alloc.free(regsview_path);

        var plan = try alloc.alloc([][]const u8, 4);
        errdefer alloc.free(plan);

        var built: usize = 0;
        errdefer {
            var i: usize = 0;
            while (i < built) : (i += 1) {
                alloc.free(plan[i]);
            }
        }

        // 0) new-session detached
        {
            var argv0 = try alloc.alloc([]const u8, 6);
            argv0[0] = "tmux";
            argv0[1] = "new-session";
            argv0[2] = "-d";
            argv0[3] = "-s";
            argv0[4] = session_name;
            argv0[5] = run_cmd; // owned
            plan[0] = argv0;
            built += 1;
        }

        // 1) split-window and run tail as the pane's program
        {
            var argv1 = try alloc.alloc([]const u8, 6);
            argv1[0] = "tmux";
            argv1[1] = "split-window";
            argv1[2] = "-h";
            argv1[3] = "-t";
            argv1[4] = try std.fmt.allocPrint(alloc, "{s}:0", .{session_name}); // owned
            argv1[5] = regs_cmd; // owned
            plan[1] = argv1;
            built += 1;
        }

        // 2) select left pane
        {
            var argv2 = try alloc.alloc([]const u8, 4);
            argv2[0] = "tmux";
            argv2[1] = "select-pane";
            argv2[2] = "-t";
            argv2[3] = try std.fmt.allocPrint(alloc, "{s}:0.0", .{session_name}); // owned
            plan[2] = argv2;
            built += 1;
        }

        // 3) attach or switch-client
        {
            var argv3 = try alloc.alloc([]const u8, 4);
            argv3[0] = "tmux";
            argv3[1] = if (inside_tmux) "switch-client" else "attach-session";
            argv3[2] = "-t";
            argv3[3] = session_name;
            plan[3] = argv3;
            built += 1;
        }

        return plan;
    }

    pub fn freePlan(alloc: std.mem.Allocator, plan: [][][]const u8) void {
        if (plan.len >= 1 and plan[0].len >= 6) alloc.free(plan[0][5]); // run_cmd
        if (plan.len >= 2 and plan[1].len >= 6) alloc.free(plan[1][5]); // tail_cmd
        if (plan.len >= 2 and plan[1].len >= 5) alloc.free(plan[1][4]); // "<session>:0"
        if (plan.len >= 3 and plan[2].len >= 4) alloc.free(plan[2][3]); // "<session>:0.0"

        for (plan) |argv| alloc.free(argv);
        alloc.free(plan);
    }

    pub fn bootstrap(
        alloc: std.mem.Allocator,
        dipole_path: []const u8,
        subcommand: []const u8,
        target: []const u8,
        extra_args: []const []const u8,
    ) !void {
        if (@hasDecl(builtin, "is_test") and builtin.is_test) return;

        if (Tmux.alreadyBootstrapped()) return;

        Log.log("Tmux.bootstrap: entered (bootstrapped=false)", .{});
        const avail = Tmux.isAvailable(alloc);
        Log.log("Tmux.bootstrap: tmux available={}", .{avail});
        if (!avail) return;

        const inside = Tmux.isInsideAnyTmux();

        const session_name = try Tmux.defaultSessionName(alloc);
        defer alloc.free(session_name);

        const reg_path = try Tmux.defaultRegPath(alloc, session_name);
        defer alloc.free(reg_path);

        Tmux.initRegFile(reg_path);

        const plan = try Tmux.planBootstrap(
            alloc,
            session_name,
            dipole_path,
            subcommand,
            target,
            extra_args,
            reg_path,
            inside,
        );
        defer Tmux.freePlan(alloc, plan);

        for (plan) |cmd| {
            var child = std.process.Child.init(cmd, alloc);
            child.stdin_behavior = .Inherit;
            child.stdout_behavior = .Inherit;
            child.stderr_behavior = .Inherit;

            const res = try child.spawnAndWait();
            switch (res) {
                .Exited => |code| if (code != 0) return,
                else => return,
            }
        }

        Log.log("Tmux.bootstrap: tmux launched session; exiting parent", .{});
        std.process.exit(0);
    }

    // ---- Helpers for quoting dipole CLI ---------------------------------------------------------

    fn buildDipoleCommandString(
        alloc: std.mem.Allocator,
        dipole_path: []const u8,
        subcommand: []const u8,
        target: []const u8,
        extra_args: []const []const u8,
    ) ![]const u8 {
        var out = std.ArrayList(u8).init(alloc);
        errdefer out.deinit();

        try appendQuoted(&out, dipole_path);
        try out.append(' ');
        try appendQuoted(&out, subcommand);
        try out.append(' ');
        try appendQuoted(&out, target);

        for (extra_args) |a| {
            try out.append(' ');
            try appendQuoted(&out, a);
        }

        return out.toOwnedSlice();
    }

    fn appendQuoted(out: *std.ArrayList(u8), s: []const u8) !void {
        const needs_quotes =
            std.mem.indexOfScalar(u8, s, ' ') != null or
            std.mem.indexOfScalar(u8, s, '\t') != null or
            std.mem.indexOfScalar(u8, s, '"') != null;

        if (!needs_quotes) {
            try out.appendSlice(s);
            return;
        }

        try out.append('"');
        for (s) |ch| {
            if (ch == '"') {
                try out.appendSlice("\\\"");
            } else {
                try out.append(ch);
            }
        }
        try out.append('"');
    }

    // ---- libc env helpers (stable across Zig stdlib versions) ----------------------------------

    fn cGetEnvExists(name: []const u8) bool {
        // getenv wants NUL-terminated name
        var buf: [128:0]u8 = undefined;
        if (name.len > buf.len) {
            // long env names are unlikely here; just treat as absent
            return false;
        }
        @memcpy(buf[0..name.len], name);
        buf[name.len] = 0;
        const name_z = buf[0..name.len :0];
        const p = std.c.getenv(name_z.ptr);
        return p != null;
    }

    fn cGetEnvDupOwned(alloc: std.mem.Allocator, name: []const u8) ?[]const u8 {
        var buf: [128:0]u8 = undefined;
        if (name.len > buf.len) return null;
        @memcpy(buf[0..name.len], name);
        buf[name.len] = 0;
        const name_z = buf[0..name.len :0];

        const p = std.c.getenv(name_z.ptr) orelse return null;
        const s = std.mem.span(p); // reads until NUL
        return alloc.dupe(u8, s) catch null;
    }

    fn cSetEnv(name: []const u8, value: []const u8) void {
        // setenv(name, value, overwrite=1)
        // Need NUL-terminated strings.
        // For tests/this file, env var names are tiny.
        var nbuf: [128:0]u8 = undefined;
        var vbuf: [512:0]u8 = undefined;
        if (name.len > nbuf.len) return;
        if (value.len > vbuf.len) return;

        @memcpy(nbuf[0..name.len], name);
        nbuf[name.len] = 0;
        @memcpy(vbuf[0..value.len], value);
        vbuf[value.len] = 0;

        const name_z = nbuf[0..name.len :0];
        const value_z = vbuf[0..value.len :0];
        const overwrite: c_int = 1;
        _ = setenv(name_z.ptr, value_z.ptr, overwrite);
    }

    fn cUnsetEnv(name: []const u8) void {
        var nbuf: [128:0]u8 = undefined;
        if (name.len > nbuf.len) return;
        @memcpy(nbuf[0..name.len], name);
        nbuf[name.len] = 0;
        const name_z = nbuf[0..name.len :0];
        _ = unsetenv(name_z.ptr);
    }
};

extern "c" fn setenv(name: [*:0]const u8, value: [*:0]const u8, overwrite: c_int) c_int;
extern "c" fn unsetenv(name: [*:0]const u8) c_int;

// ------------------------------------------------------------------------------------------------
// Tests
// ------------------------------------------------------------------------------------------------

fn envGetOwnedOrNull(alloc: std.mem.Allocator, name: []const u8) ?[]const u8 {
    return Tmux.cGetEnvDupOwned(alloc, name);
}

test "currentRegPathOwned prefers DIPOLE_REG_PATH when set" {
    const alloc = std.testing.allocator;

    const old = envGetOwnedOrNull(alloc, Tmux.env_reg_path);
    defer if (old) |v| alloc.free(v);

    defer {
        if (old) |v| {
            Tmux.cSetEnv(Tmux.env_reg_path, v);
        } else {
            Tmux.cUnsetEnv(Tmux.env_reg_path);
        }
    }

    Tmux.cSetEnv(Tmux.env_reg_path, "/tmp/dipole_regs_env.txt");

    const p = try Tmux.currentRegPathOwned(alloc);
    defer alloc.free(p);

    try std.testing.expectEqualStrings("/tmp/dipole_regs_env.txt", p);
}

test "currentRegPathOwned falls back to defaultRegPath format when env not set" {
    const alloc = std.testing.allocator;

    const old = envGetOwnedOrNull(alloc, Tmux.env_reg_path);
    defer if (old) |v| alloc.free(v);

    // Ensure unset for this test.
    Tmux.cUnsetEnv(Tmux.env_reg_path);

    defer {
        if (old) |v| {
            Tmux.cSetEnv(Tmux.env_reg_path, v);
        } else {
            Tmux.cUnsetEnv(Tmux.env_reg_path);
        }
    }

    const p = try Tmux.currentRegPathOwned(alloc);
    defer alloc.free(p);

    try std.testing.expect(std.mem.startsWith(u8, p, "/tmp/dipole_regs_dipole-"));
    try std.testing.expect(std.mem.endsWith(u8, p, ".txt"));
}

test "planBootstrap builds 2-pane tmux plan (new-session + split-window + select-pane + attach) when outside tmux" {
    const alloc = std.testing.allocator;

    const session_name = "dipole-123";
    const reg_path = "/tmp/dipole_regs_dipole-123.txt";

    const plan = try Tmux.planBootstrap(
        alloc,
        session_name,
        "/dipole",
        "run",
        "./a.out",
        &.{ "one", "hello world" },
        reg_path,
        false, // inside_tmux
    );
    defer Tmux.freePlan(alloc, plan);

    try std.testing.expectEqual(@as(usize, 4), plan.len);

    try std.testing.expectEqualStrings("tmux", plan[0][0]);
    try std.testing.expectEqualStrings("new-session", plan[0][1]);
    try std.testing.expectEqualStrings("-d", plan[0][2]);
    try std.testing.expectEqualStrings("-s", plan[0][3]);
    try std.testing.expectEqualStrings(session_name, plan[0][4]);

    const wrapped = plan[0][5];
    try std.testing.expect(std.mem.containsAtLeast(u8, wrapped, 1, "bash -lc '"));
    try std.testing.expect(std.mem.containsAtLeast(u8, wrapped, 1, Tmux.sentinel_bootstrapped));
    try std.testing.expect(std.mem.containsAtLeast(u8, wrapped, 1, Tmux.env_session));
    try std.testing.expect(std.mem.containsAtLeast(u8, wrapped, 1, session_name));
    try std.testing.expect(std.mem.containsAtLeast(u8, wrapped, 1, Tmux.env_reg_path));
    try std.testing.expect(std.mem.containsAtLeast(u8, wrapped, 1, reg_path));
    try std.testing.expect(std.mem.containsAtLeast(u8, wrapped, 1, "/dipole"));
    try std.testing.expect(std.mem.containsAtLeast(u8, wrapped, 1, "run"));
    try std.testing.expect(std.mem.containsAtLeast(u8, wrapped, 1, "./a.out"));
    try std.testing.expect(std.mem.containsAtLeast(u8, wrapped, 1, "\"hello world\""));

    try std.testing.expectEqualStrings("tmux", plan[1][0]);
    try std.testing.expectEqualStrings("split-window", plan[1][1]);
    try std.testing.expectEqualStrings("-h", plan[1][2]);
    try std.testing.expectEqualStrings("-t", plan[1][3]);
    try std.testing.expect(std.mem.containsAtLeast(u8, plan[1][4], 1, session_name));
    try std.testing.expect(std.mem.containsAtLeast(u8, plan[1][4], 1, ":0"));

    const regs_cmd = plan[1][5];
    try std.testing.expect(std.mem.containsAtLeast(u8, regs_cmd, 1, "bash -lc"));
    try std.testing.expect(std.mem.containsAtLeast(u8, regs_cmd, 1, "dipole-regsview"));
    try std.testing.expect(std.mem.containsAtLeast(u8, regs_cmd, 1, "--path"));
    try std.testing.expect(std.mem.containsAtLeast(u8, regs_cmd, 1, reg_path));

    try std.testing.expectEqualStrings("tmux", plan[2][0]);
    try std.testing.expectEqualStrings("select-pane", plan[2][1]);
    try std.testing.expectEqualStrings("-t", plan[2][2]);
    try std.testing.expect(std.mem.containsAtLeast(u8, plan[2][3], 1, session_name));
    try std.testing.expect(std.mem.containsAtLeast(u8, plan[2][3], 1, ":0.0"));

    try std.testing.expectEqualStrings("tmux", plan[3][0]);
    try std.testing.expectEqualStrings("attach-session", plan[3][1]);
    try std.testing.expectEqualStrings("-t", plan[3][2]);
    try std.testing.expectEqualStrings(session_name, plan[3][3]);
}

test "planBootstrap uses switch-client when already inside tmux" {
    const alloc = std.testing.allocator;

    const session_name = "dipole-999";
    const reg_path = "/tmp/dipole_regs_dipole-999.txt";

    const plan = try Tmux.planBootstrap(
        alloc,
        session_name,
        "/dipole",
        "run",
        "./a.out",
        &.{},
        reg_path,
        true, // inside_tmux
    );
    defer Tmux.freePlan(alloc, plan);

    try std.testing.expectEqual(@as(usize, 4), plan.len);

    try std.testing.expectEqualStrings("tmux", plan[3][0]);
    try std.testing.expectEqualStrings("switch-client", plan[3][1]);
    try std.testing.expectEqualStrings("-t", plan[3][2]);
    try std.testing.expectEqualStrings(session_name, plan[3][3]);
}

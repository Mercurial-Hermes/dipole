const std = @import("std");
const mem = std.mem;
const LLDBDriver = @import("lib").LLDBDriver;

/// ─────────────────────────────────────────────────────────────────────────────
/// Utility: Get username (used by process picker)
fn getUserName(allocator: std.mem.Allocator) ![]const u8 {
    var env = try std.process.getEnvMap(allocator);
    defer env.deinit();

    const val = env.get("USER") orelse "unknown";
    if (std.mem.eql(u8, val, "unknown")) {
        return val;
    }
    return try allocator.dupe(u8, val);
}

/// ─────────────────────────────────────────────────────────────────────────────
/// Interactive process picker (reuse your existing implementation)
fn pickPidInteractive(allocator: std.mem.Allocator) !i32 {
    var cmd = std.ArrayList([]const u8).init(allocator);
    defer cmd.deinit();

    const user = try getUserName(allocator);
    defer if (!std.mem.eql(u8, user, "unknown")) allocator.free(user);

    try cmd.append("ps");
    try cmd.append("-U");
    try cmd.append(user);
    try cmd.append("-o");
    try cmd.append("pid,tty,comm");

    var child = std.process.Child.init(cmd.items, allocator);
    child.stdin_behavior = .Inherit;
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Inherit;
    try child.spawn();

    var out_buf = std.ArrayList(u8).init(allocator);
    defer out_buf.deinit();

    if (child.stdout) |pipe| {
        var reader = pipe.reader();
        var tmp: [1024]u8 = undefined;

        while (true) {
            const n = try reader.read(&tmp);
            if (n == 0) break;
            try out_buf.appendSlice(tmp[0..n]);
        }
    }

    _ = try child.wait();

    // Print the filtered process list
    var iter = std.mem.splitScalar(u8, out_buf.items, '\n');
    while (iter.next()) |line| {
        if (line.len == 0) continue;
        if (std.mem.indexOf(u8, line, "??") != null) continue;
        try std.io.getStdOut().writer().print("{s}\n", .{line});
    }

    // Prompt for PID
    std.debug.print("\n[Dipole] Enter PID to attach (empty = cancel): ", .{});
    var stdin_reader = std.io.getStdIn().reader();
    var buf_in: [64]u8 = undefined;

    const maybe_line = try stdin_reader.readUntilDelimiterOrEof(&buf_in, '\n');
    const line = maybe_line orelse return error.InvalidArguments;

    const trimmed = std.mem.trim(u8, line, " \t\r\n");
    if (trimmed.len == 0) return error.InvalidArguments;

    return try std.fmt.parseInt(i32, trimmed, 10);
}

/// ─────────────────────────────────────────────────────────────────────────────
/// Pretty-print LLDB output from driver buffer
fn printLLDBOutput(output: []const u8) !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.writeAll(output);
}

fn is(raw: []const u8, a: []const u8, b: []const u8) bool {
    return mem.eql(u8, raw, a) or mem.eql(u8, raw, b);
}

fn parseZigMainSymbol(output: []const u8) !struct { file: []const u8, line: usize } {
    var it = std.mem.tokenizeAny(u8, output, "\n");
    while (it.next()) |line| {
        // Look only for entries pointing to user Zig source files
        if (std.mem.indexOf(u8, line, " at ") != null and
            std.mem.endsWith(u8, line, ".zig:") == false)
        {
            // Example line:
            // "Summary: exit_0_zig`exit_0.main at exit_0.zig:4"
            if (std.mem.indexOf(u8, line, " at ")) |idx| {
                const after_at = line[idx + 4 ..]; // skip " at "
                if (std.mem.indexOfScalar(u8, after_at, ':')) |colon| {
                    const file = after_at[0..colon];
                    const line_str = after_at[colon + 1 ..];
                    const ln = try std.fmt.parseInt(usize, line_str, 10);
                    return .{ .file = file, .line = ln };
                }
            }
        }
    }
    return error.MainNotFound;
}

/// ─────────────────────────────────────────────────────────────────────────────
/// Crash summary helpers
const CrashKind = enum { sigabrt, sigsegv, sigbus, sigill, sigfpe, exc_bad_access, unknown };

const CrashSummary = struct {
    signal: CrashKind,
    signal_name: []const u8,
    location_line: ?[]const u8 = null,
    detail_line: ?[]const u8 = null,
    summary: []const u8,
};

const CrashCache = struct {
    allocator: std.mem.Allocator,
    last: ?CrashSummary = null,

    fn set(self: *CrashCache, new: CrashSummary) !void {
        // Free existing allocations before replacing
        if (self.last) |prev| {
            self.allocator.free(prev.summary);
            if (prev.location_line) |l| self.allocator.free(l);
            if (prev.detail_line) |d| self.allocator.free(d);
        }
        self.last = new;
    }

    fn clear(self: *CrashCache) void {
        if (self.last) |prev| {
            self.allocator.free(prev.summary);
            if (prev.location_line) |l| self.allocator.free(l);
            if (prev.detail_line) |d| self.allocator.free(d);
        }
        self.last = null;
    }
};

fn detectCrashKind(out: []const u8) ?struct { kind: CrashKind, name: []const u8 } {
    const pairs = [_]struct { name: []const u8, kind: CrashKind }{
        .{ .name = "SIGABRT", .kind = .sigabrt },
        .{ .name = "SIGSEGV", .kind = .sigsegv },
        .{ .name = "SIGBUS", .kind = .sigbus },
        .{ .name = "SIGILL", .kind = .sigill },
        .{ .name = "SIGFPE", .kind = .sigfpe },
        .{ .name = "EXC_BAD_ACCESS", .kind = .exc_bad_access },
    };

    for (pairs) |p| {
        if (std.mem.containsAtLeast(u8, out, 1, p.name)) {
            return .{ .kind = p.kind, .name = p.name };
        }
    }

    // Zig panics print "panic:"; treat as abort-like.
    if (std.mem.containsAtLeast(u8, out, 1, "panic:")) {
        return .{ .kind = .sigabrt, .name = "panic" };
    }

    // LLDB sometimes reports "stop reason = signal SIGSEGV" in lowercase
    if (std.mem.containsAtLeast(u8, out, 1, "sigsegv")) return .{ .kind = .sigsegv, .name = "SIGSEGV" };
    if (std.mem.containsAtLeast(u8, out, 1, "sigabrt")) return .{ .kind = .sigabrt, .name = "SIGABRT" };

    return null;
}

fn extractLine(allocator: std.mem.Allocator, out: []const u8, needle: []const u8) !?[]const u8 {
    var it = std.mem.tokenizeAny(u8, out, "\n");
    while (it.next()) |line| {
        if (std.mem.containsAtLeast(u8, line, 1, needle)) {
            return try allocator.dupe(u8, line);
        }
    }
    return null;
}

fn buildCrashSummary(
    allocator: std.mem.Allocator,
    out: []const u8,
) !?CrashSummary {
    const detected = detectCrashKind(out) orelse return null;

    const location = try extractLine(allocator, out, ".c:") orelse
        try extractLine(allocator, out, ".zig:");
    const detail = try extractLine(allocator, out, "panic:") orelse
        try extractLine(allocator, out, "stop reason") orelse null;

    var buf = std.ArrayList(u8).init(allocator);
    errdefer buf.deinit();

    const w = buf.writer();
    try w.print(
        \\[Dipole] Crash detected
        \\Signal: {s}
        \\
    , .{detected.name});

    if (location) |loc| {
        try w.print("Location: {s}\n", .{loc});
    }
    if (detail) |d| {
        try w.print("Detail: {s}\n", .{d});
    }

    // Light guidance
    switch (detected.kind) {
        .sigabrt, .sigsegv, .sigbus, .exc_bad_access => try w.writeAll(
            "Hint: likely an invalid memory access. Use 'regs' and 'bt' to inspect state.\n"),
        .sigill => try w.writeAll(
            "Hint: illegal instruction. Check disassembly and CPU state.\n"),
        .sigfpe => try w.writeAll(
            "Hint: arithmetic fault (divide-by-zero?). Inspect operands and registers.\n"),
        .unknown => {},
    }

    try w.writeAll("Next steps: regs | bt | lldb disassemble -p | why\n");

    const summary = try buf.toOwnedSlice();

    return CrashSummary{
        .signal = detected.kind,
        .signal_name = detected.name,
        .location_line = location,
        .detail_line = detail,
        .summary = summary,
    };
}

/// ─────────────────────────────────────────────────────────────────────────────
/// Dipole REPL
fn replLoop(driver: *LLDBDriver, crash_cache: *CrashCache) !void {
    var stdin_reader = std.io.getStdIn().reader();
    var input_buf: [512]u8 = undefined;

    const stdout = std.io.getStdOut().writer();

    while (true) {
        try stdout.print("dipole[{s}]> ", .{@tagName(driver.state)});
        const maybe_line = try stdin_reader.readUntilDelimiterOrEof(&input_buf, '\n');
        if (maybe_line == null) break;

        const raw = std.mem.trim(u8, maybe_line.?, " \t\r\n");
        if (raw.len == 0) continue;

        // Built-in dipole commands
        if (is(raw, "quit", "q")) {
            try stdout.writeAll("[Dipole] Shutting down...\n");
            try driver.shutdown();
            return;
        } else if (is(raw, "help", "h")) {
            try stdout.writeAll(
                \\Dipole REPL Commands:
                \\  help            : Show this help
                \\  step            : lldb 'step'
                \\  next            : lldb 'next'
                \\  continue        : lldb 'continue'
                \\  regs            : lldb 'register read'
                \\  bt              : lldb 'bt'
                \\  why             : show last crash summary (if any)
                \\  lldb <cmd>      : Send raw command to LLDB
                \\  quit            : Exit dipole and terminate lldb
                \\
            );
            continue;
        } else if (is(raw, "why", "why")) {
            if (crash_cache.last) |cinfo| {
                try stdout.writeAll(cinfo.summary);
            } else {
                try stdout.writeAll("[Dipole] No crash summary yet.\n");
            }
            continue;
        } else if (is(raw, "step", "s")) {
            if (driver.state == .Running) {
                try stdout.writeAll("[Dipole] Program is running. Use 'pause' or wait for it to stop.\n");
                continue;
            }
            try driver.sendLine("step");
        } else if (is(raw, "next", "n")) {
            if (driver.state == .Running) {
                try stdout.writeAll("[Dipole] Program is running. Use 'pause' or wait for it to stop.\n");
                continue;
            }
            try driver.sendLine("next");
        } else if (is(raw, "continue", "c")) {
            if (driver.state != .Stopped) {
                try stdout.writeAll("[Dipole] Cannot continue — program is not stopped.\n");
                continue;
            }

            try driver.sendLine("continue");
            // Now wait for LLDB to stop OR exit:
            const output = try driver.readUntilPrompt(.LldbPrompt);

            // If the inferior exited, your logic already sets driver.state = .Exited
            // If it hit a breakpoint or step stop, state = .Stopped
            if (driver.state == .Exited) {
                try stdout.writeAll("[Dipole] Program exited.\n");
            } else {
                try stdout.writeAll("[Dipole] Program stopped.\n");
            }

            try stdout.writeAll(output);
            try stdout.writeAll("\n");

            if (try buildCrashSummary(driver.allocator, output)) |crash| {
                try crash_cache.set(crash);
                try stdout.writeAll(crash.summary);
            }
            continue;
        } else if (is(raw, "regs", "rg")) {
            if (driver.state == .Running) {
                try stdout.writeAll("[Dipole] Program is running. Use 'pause' or wait for it to stop.\n");
                continue;
            }
            try driver.sendLine("register read");
        } else if (is(raw, "bt", "backtrace")) {
            if (driver.state == .Running) {
                try stdout.writeAll("[Dipole] Program is running. Use 'pause' or wait for it to stop.\n");
                continue;
            }
            try driver.sendLine("bt");
        } else if (is(raw, "pause", "p")) {
            if (driver.state != .Running) {
                try stdout.writeAll("[Dipole] Program is not running.\n");
                continue;
            }

            try driver.interrupt();
            try stdout.writeAll("[Dipole] Interrupt sent. Waiting for stop...\n");

            const out = try driver.readUntilPrompt(.LldbPrompt);
            try printLLDBOutput(out);

            driver.state = .Stopped;

            if (try buildCrashSummary(driver.allocator, out)) |crash| {
                try crash_cache.set(crash);
                try stdout.writeAll("\n");
                try stdout.writeAll(crash.summary);
            }
            continue;
        } else {
            // Raw LLDB commands: "lldb print 1+2"
            if (std.mem.startsWith(u8, raw, "lldb ")) {
                const cmd = std.mem.trimLeft(u8, raw["lldb ".len..], " ");
                try driver.sendLine(cmd);
            } else {
                try stdout.writeAll("[Dipole] Unknown command. Try 'help'.\n");
                continue;
            }
        }

        // Read output
        const out = try driver.readUntilPrompt(.LldbPrompt);
        try printLLDBOutput(out);

        if (try buildCrashSummary(driver.allocator, out)) |crash| {
            try crash_cache.set(crash);
            try stdout.writeAll("\n");
            try stdout.writeAll(crash.summary);
        }
    }
}

/// ─────────────────────────────────────────────────────────────────────────────
/// Main entrypoint
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();
    var crash_cache = CrashCache{ .allocator = allocator };
    defer crash_cache.clear();

    var args = std.process.args();
    _ = args.next(); // skip executable name

    const stdout = std.io.getStdOut().writer();

    const subcmd = args.next() orelse {
        // Default: pick process + attach
        const pid = try pickPidInteractive(allocator);
        try stdout.print("[Dipole] Attaching to PID {d}...\n", .{pid});

        var driver = try LLDBDriver.initAttach(allocator, pid);
        defer driver.deinit();

        _ = try driver.waitForPrompt();
        try stdout.writeAll("[Dipole] Attached. Entering REPL.\n\n");

        try replLoop(&driver, &crash_cache);
        return;
    };

    // ───── dipole ps
    if (std.mem.eql(u8, subcmd, "ps")) {
        _ = try pickPidInteractive(allocator);
        return;
    }

    // ───── dipole attach <pid>
    if (std.mem.eql(u8, subcmd, "attach")) {
        const pid_str = args.next() orelse {
            return error.InvalidArguments;
        };
        const pid = try std.fmt.parseInt(i32, pid_str, 10);

        try stdout.print("[Dipole] Attaching to PID {d}...\n", .{pid});

        var driver = try LLDBDriver.initAttach(allocator, pid);
        defer driver.deinit();

        _ = try driver.waitForPrompt();
        try stdout.writeAll("[Dipole] Attached. Entering REPL.\n\n");

        try replLoop(&driver, &crash_cache);
        return;
    }

    // ───── dipole run <exe> [args...]
    if (std.mem.eql(u8, subcmd, "run")) {
        const exe = args.next() orelse {
            return error.InvalidArguments;
        };

        // Collect all remaining CLI arguments
        var arg_list = std.ArrayList([]const u8).init(allocator);
        defer arg_list.deinit();

        while (args.next()) |a| {
            try arg_list.append(a);
        }

        const exe_args = arg_list.items;

        try stdout.print("[Dipole] Launching {s} under LLDB...\n", .{exe});

        var driver = try LLDBDriver.initLaunch(allocator, exe, exe_args);
        defer driver.deinit();

        const banner = try driver.waitForPrompt();
        try printLLDBOutput(banner);

        // ─────────────────────────────────────────────────────────────
        // Resolve the *real* user main function using LLDB introspection
        // Zig produces two main symbols: start.main (runtime) and main (user)
        // We find the one whose source file is a Zig file and NOT start.zig.
        // ─────────────────────────────────────────────────────────────

        // 1. Ask LLDB about all symbols named "main"
        try driver.sendLine("image lookup -n main");
        const lookup = try driver.readUntilPrompt(.LldbPrompt);

        var file: []const u8 = "";
        var line: usize = 0;

        // 2. Parse LLDB output
        {
            var iter = std.mem.splitScalar(u8, lookup, '\n');
            while (iter.next()) |line_text| {
                // Look for lines like:
                //   Summary: exit_0_zig`exit_0.main at exit_0.zig:4
                if (std.mem.indexOf(u8, line_text, " at ")) |idx| {
                    const after_at = std.mem.trim(u8, line_text[idx + 4 ..], " \t\r\n");

                    // skip Zig internal start.zig
                    if (std.mem.containsAtLeast(u8, after_at, 1, "start.zig"))
                        continue;

                    if (std.mem.lastIndexOfScalar(u8, after_at, ':')) |colon| {
                        const line_str_full = std.mem.trim(u8, after_at[colon + 1 ..], " \t\r\n");

                        // Some LLDB lines can contain non-digit suffixes; keep leading digits only.
                        var digit_len: usize = 0;
                        while (digit_len < line_str_full.len and std.ascii.isDigit(line_str_full[digit_len])) {
                            digit_len += 1;
                        }
                        if (digit_len == 0)
                            continue;

                        file = after_at[0 .. colon];
                        line = try std.fmt.parseInt(usize, line_str_full[0..digit_len], 10);
                        break;
                    }
                }
            }
        }

        if (file.len == 0)
            return error.CouldNotResolveMain;

        // 3. Set breakpoint at the correct file + line
        var bp_buf: [256]u8 = undefined;
        const bp_cmd = try std.fmt.bufPrint(
            &bp_buf,
            "breakpoint set --file {s} --line {d}",
            .{ file, line },
        );

        try driver.sendLine(bp_cmd);
        const bp_out = try driver.readUntilPrompt(.LldbPrompt);
        try printLLDBOutput(bp_out);

        // ─────────────────────────────────────────────────────────────
        // Now run with args
        // ─────────────────────────────────────────────────────────────

        var run_buf = std.ArrayList(u8).init(allocator);
        defer run_buf.deinit();
        try run_buf.appendSlice("run");

        for (exe_args) |a| {
            try run_buf.append(' ');
            try run_buf.appendSlice(a);
        }

        try driver.sendLine(run_buf.items);

        const run_out = try driver.readUntilPrompt(.LldbPrompt);
        try printLLDBOutput(run_out);

        try stdout.writeAll("[Dipole] Program launched and stopped at main. Entering REPL.\n\n");

        try replLoop(&driver, &crash_cache);
        return;
    }

    // Unknown subcommand
    try stdout.writeAll(
        "Usage:\n" ++
            "  dipole              (process picker + attach)\n" ++
            "  dipole ps           (list processes)\n" ++
            "  dipole attach <pid> (attach to running process)\n" ++
            "  dipole run <exe>    (launch executable)\n",
    );
}

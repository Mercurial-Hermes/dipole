const std = @import("std");
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

/// ─────────────────────────────────────────────────────────────────────────────
/// Dipole REPL
fn replLoop(driver: *LLDBDriver) !void {
    var stdin_reader = std.io.getStdIn().reader();
    var input_buf: [512]u8 = undefined;

    const stdout = std.io.getStdOut().writer();

    while (true) {
        try stdout.writeAll("dipole> ");
        const maybe_line = try stdin_reader.readUntilDelimiterOrEof(&input_buf, '\n');
        if (maybe_line == null) break;

        const raw = std.mem.trim(u8, maybe_line.?, " \t\r\n");
        if (raw.len == 0) continue;

        // Built-in dipole commands
        if (std.mem.eql(u8, raw, "quit")) {
            try stdout.writeAll("[Dipole] Shutting down...\n");
            try driver.shutdown();
            return;
        } else if (std.mem.eql(u8, raw, "help")) {
            try stdout.writeAll(
                \\Dipole REPL Commands:
                \\  help            : Show this help
                \\  step            : lldb 'step'
                \\  next            : lldb 'next'
                \\  continue        : lldb 'continue'
                \\  regs            : lldb 'register read'
                \\  bt              : lldb 'bt'
                \\  lldb <cmd>      : Send raw command to LLDB
                \\  quit            : Exit dipole and terminate lldb
                \\
            );
            continue;
        } else if (std.mem.eql(u8, raw, "step")) {
            try driver.sendLine("step");
        } else if (std.mem.eql(u8, raw, "next")) {
            try driver.sendLine("next");
        } else if (std.mem.eql(u8, raw, "continue")) {
            try driver.sendLine("continue");
            // DO NOT wait for prompt here — program is running.
            try stdout.writeAll("[Dipole] Program continued. Waiting for stop event.\n");
            continue; // return to REPL immediately
        } else if (std.mem.eql(u8, raw, "regs")) {
            try driver.sendLine("register read");
        } else if (std.mem.eql(u8, raw, "bt")) {
            try driver.sendLine("bt");
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
    }
}

/// ─────────────────────────────────────────────────────────────────────────────
/// Main entrypoint
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

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

        try replLoop(&driver);
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

        try replLoop(&driver);
        return;
    }

    // ───── dipole run <exe>
    if (std.mem.eql(u8, subcmd, "run")) {
        const exe = args.next() orelse {
            return error.InvalidArguments;
        };

        try stdout.print("[Dipole] Launching {s} under LLDB...\n", .{exe});

        var driver = try LLDBDriver.initLaunch(allocator, exe, &.{});
        defer driver.deinit();

        const banner = try driver.waitForPrompt();
        try printLLDBOutput(banner);

        try driver.sendLine("breakpoint set -n main");
        const bp_out = try driver.readUntilPrompt(.LldbPrompt);
        try printLLDBOutput(bp_out);

        try driver.sendLine("run");
        const run_out = try driver.readUntilPrompt(.LldbPrompt);
        try printLLDBOutput(run_out);

        try stdout.writeAll("[Dipole] Program launched and stopped at main. Entering REPL.\n\n");

        try replLoop(&driver);
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

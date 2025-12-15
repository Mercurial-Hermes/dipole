const std = @import("std");
const Tui = @import("tui").Tui;
const LLDBDriver = @import("lldbdriver").LLDBDriver;

//
// ───────────────────────────────────────────────────────────────
//  GLOBALS FOR REGISTER SNAPSHOT FILE
// ───────────────────────────────────────────────────────────────
//
var regs_path: ?[]u8 = null;

fn cleanupRegsFile(alloc: std.mem.Allocator) void {
    if (regs_path) |p| {
        _ = std.fs.deleteFileAbsolute(p) catch {};
        alloc.free(p);
        regs_path = null;
    }
}

//
// ───────────────────────────────────────────────────────────────
//  DETECTION HELPERS
// ───────────────────────────────────────────────────────────────
//

fn isGhostty(alloc: std.mem.Allocator) bool {
    const term = std.process.getEnvVarOwned(alloc, "TERM") catch "";
    defer if (term.len > 0) alloc.free(term);
    return term.len > 0 and std.mem.eql(u8, term, "xterm-ghostty");
}

fn tmuxAvailable(alloc: std.mem.Allocator) bool {
    var c = std.process.Child.init(&.{ "tmux", "-V" }, alloc);
    c.stdin_behavior = .Ignore;
    c.stdout_behavior = .Ignore;
    c.stderr_behavior = .Ignore;
    return (c.spawnAndWait() catch return false) == .Exited;
}

//
// ───────────────────────────────────────────────────────────────
//  REGISTER VIEWER MODE
//  dipole --regs-view <file>
//  Runs *inside* tmux pane 1. No LLDB.
// ───────────────────────────────────────────────────────────────
//

fn runRegsViewer(path: []const u8) !void {
    const out = std.io.getStdOut().writer();

    while (true) {
        try out.writeAll("\x1b[2J\x1b[H");

        if (std.fs.openFileAbsolute(path, .{}) catch null) |f| {
            defer f.close();

            var buf: [4096]u8 = undefined;
            while (true) {
                const n = f.read(&buf) catch 0;
                if (n == 0) break;
                _ = out.write(buf[0..n]) catch {};
            }
        } else {
            try out.writeAll("(waiting for registers...)\n");
        }
        std.time.sleep(200_000_000); // 200ms
    }
}

//
// ───────────────────────────────────────────────────────────────
//  WRITE SNAPSHOT (called only by REPL mode)
// ───────────────────────────────────────────────────────────────
//

fn writeRegsSnapshot(driver: *LLDBDriver) void {
    const path = regs_path orelse return;

    if (driver.state == .Exited) return;

    driver.sendLine("register read") catch return;
    const regs = driver.readUntilPrompt(.LldbPrompt) catch return;

    const f = std.fs.createFileAbsolute(path, .{
        .truncate = true,
        .mode = 0o644,
    }) catch return;
    defer f.close();

    _ = f.write(regs) catch {};
}

fn extractPidFromRunOutput(out: []const u8) ?i32 {
    const needle = "Process ";
    if (std.mem.indexOf(u8, out, needle)) |i| {
        const rest = out[i + needle.len ..];

        var pid: i32 = 0;
        var found = false;

        for (rest) |c| {
            if (c >= '0' and c <= '9') {
                pid = pid * 10 + @as(i32, c - '0');
                found = true;
            } else break;
        }

        if (found) return pid;
    }
    return null;
}

//
// ───────────────────────────────────────────────────────────────
//  TUI + REPL MODE
//  dipole run ./exe --repl-mode
//  Runs inside tmux pane 0
// ───────────────────────────────────────────────────────────────
//

fn replMode(
    driver: *LLDBDriver,
    banner: ?[]const u8,
    alloc: std.mem.Allocator,
) !void {
    var tui = try Tui.init(alloc);
    defer tui.deinit();

    if (isGhostty(alloc)) tui.enabled = true;

    // create regs file path
    {
        const path = try std.fmt.allocPrint(
            alloc,
            "/tmp/dipole_regs_{d}.txt",
            .{driver.target_pid},
        );
        regs_path = path;
    }

    // initial content
    if (banner) |b| {
        try tui.setOutput(b);
    } else {
        try tui.setOutput("Ready.");
    }

    // initial snapshot
    writeRegsSnapshot(driver);

    const stdin = std.io.getStdIn().reader();
    var cmd_buf: [512]u8 = undefined;

    var cmd_input = std.ArrayList(u8).init(alloc);
    defer cmd_input.deinit();

    const stdout = std.io.getStdOut().writer();

    while (true) {
        if (tui.enabled) {
            try tui.redraw(@tagName(driver.state), driver.target_pid, cmd_input.items);
        } else {
            try stdout.print("dipole[{s}]> ", .{@tagName(driver.state)});
        }

        const maybe_line = try stdin.readUntilDelimiterOrEof(&cmd_buf, '\n');
        if (maybe_line == null) break;

        const raw = std.mem.trim(u8, maybe_line.?, " \t\r\n");
        if (raw.len == 0) {
            cmd_input.clearRetainingCapacity();
            continue;
        }

        cmd_input.clearRetainingCapacity();
        try cmd_input.appendSlice(raw);

        // Quit
        if (std.mem.eql(u8, raw, "q") or std.mem.eql(u8, raw, "quit")) {
            try stdout.writeAll("[Dipole] Shutting down...\n");
            try driver.shutdown();
            // Kill tmux session
            _ = std.process.Child.run(.{
                .allocator = alloc,
                .argv = &.{ "tmux", "kill-session", "-t", "dipole" },
            }) catch {};
            cleanupRegsFile(alloc);
            return;
        }

        // step
        if (std.mem.eql(u8, raw, "step") or std.mem.eql(u8, raw, "s")) {
            try driver.sendLine("step");
        }
        // next
        else if (std.mem.eql(u8, raw, "next") or std.mem.eql(u8, raw, "n")) {
            try driver.sendLine("next");
        }
        // continue
        else if (std.mem.eql(u8, raw, "c") or std.mem.eql(u8, raw, "continue")) {
            try driver.sendLine("continue");
        }
        // regs (forced refresh)
        else if (std.mem.eql(u8, raw, "regs") or std.mem.eql(u8, raw, "rg")) {
            writeRegsSnapshot(driver);
            try tui.setOutput("Registers refreshed.");
        }
        // bt
        else if (std.mem.eql(u8, raw, "bt")) {
            try driver.sendLine("bt");
        }
        // raw LLDB
        else if (std.mem.startsWith(u8, raw, "lldb ")) {
            const cmd = raw["lldb ".len..];
            try driver.sendLine(cmd);
        } else {
            try stdout.writeAll("[Dipole] Unknown command\n");
            continue;
        }

        // Always read output
        const out = try driver.readUntilPrompt(.LldbPrompt);
        try tui.setOutput(out);

        // frame info if stopped
        if (driver.state == .Stopped) {
            try driver.sendLine("frame info");
            const fi = try driver.readUntilPrompt(.LldbPrompt);
            try tui.appendOutput("\n");
            try tui.appendOutput(fi);
        }

        // refresh register pane file
        writeRegsSnapshot(driver);

        cmd_input.clearRetainingCapacity();
    }
}

//
// ───────────────────────────────────────────────────────────────
//  TMUX BOOTSTRAP
//  Creates session, splits, launches viewer, then attaches user
// ───────────────────────────────────────────────────────────────
//

fn maybeBootstrapTmux(
    alloc: std.mem.Allocator,
    pid: i32,
    dipole_path: []const u8,
    exe: []const u8,
) !void {
    // Must have tmux
    var c = std.process.Child.init(&.{ "tmux", "-V" }, alloc);
    c.stdin_behavior = .Ignore;
    c.stdout_behavior = .Ignore;
    c.stderr_behavior = .Ignore;
    if ((c.spawnAndWait() catch return) != .Exited) return;

    // Avoid recursion
    if (std.process.hasEnvVarConstant("TMUX")) return;

    //
    // Create register snapshot path
    //
    const regfile = try std.fmt.allocPrint(
        alloc,
        "/tmp/dipole_regs_{d}.txt",
        .{pid},
    );
    const reg_env = try std.fmt.allocPrint(alloc, "DIPOLE_REGFILE={s}", .{regfile});
    defer alloc.free(reg_env);

    {
        const f = std.fs.createFileAbsolute(regfile, .{ .truncate = true }) catch return;
        defer f.close();
        _ = f.write("(waiting for registers...)\n") catch {};
    }

    //
    // NEW SESSION — pane 0 runs REPL directly
    //
    const repl_cmd = try std.fmt.allocPrint(
        alloc,
        "env {s} {s} --repl-mode run {s}",
        .{ reg_env, dipole_path, exe },
    );
    defer alloc.free(repl_cmd);

    // Start from a clean session if one is lingering
    {
        var kill = std.process.Child.init(&.{ "tmux", "kill-session", "-t", "dipole" }, alloc);
        _ = kill.spawnAndWait() catch {};
    }

    var s = std.process.Child.init(
        &.{ "tmux", "new-session", "-d", "-s", "dipole", "sh", "-c", repl_cmd },
        alloc,
    );
    _ = try s.spawnAndWait();

    //
    // SPLIT RIGHT PANE → register viewer
    //
    const cmd = try std.fmt.allocPrint(
        alloc,
        "{s} --regs-view {s}",
        .{ dipole_path, regfile },
    );
    defer alloc.free(cmd);

    var sp = std.process.Child.init(
        &.{ "tmux", "split-window", "-h", "-t", "dipole", "env", reg_env, "sh", "-c", cmd },
        alloc,
    );
    _ = try sp.spawnAndWait();

    //
    // Focus pane 0 (REPL)
    //
    var fp = std.process.Child.init(
        &.{ "tmux", "select-pane", "-t", "dipole:.0" },
        alloc,
    );
    _ = try fp.spawnAndWait();

    // Keep panes open on exit so we can see failures
    var opt = std.process.Child.init(&.{ "tmux", "set-option", "-t", "dipole", "remain-on-exit", "on" }, alloc);
    _ = try opt.spawnAndWait();
}

//
// ───────────────────────────────────────────────────────────────
//  MAIN ENTRY
// ───────────────────────────────────────────────────────────────
//

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    defer cleanupRegsFile(alloc);

    const dipole_path = try std.fs.selfExePathAlloc(alloc);
    defer alloc.free(dipole_path);

    //
    // Load args
    //
    const argv = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, argv);

    if (argv.len == 1) {
        std.debug.print("Usage: dipole run <exe> [args]\n", .{});
        return;
    }

    const cmd = argv[1];

    //
    // REG VIEW MODE
    //
    if (std.mem.eql(u8, cmd, "--regs-view")) {
        if (argv.len < 3) return error.InvalidArguments;
        try runRegsViewer(argv[2]);
        return;
    }

    //
    // REPL MODE (inside tmux)
    //
    if (std.mem.eql(u8, cmd, "--repl-mode")) {
        std.debug.print("[Dipole] Entering REPL mode...\n", .{});

        // We must infer executable + args + pid from LLDB Driver start.
        // The calling bootstrap guarantees we call "dipole run <exe> --repl-mode"
        // So argv[2] is "run", argv[3] is exe, argv[4..] are exe args but not needed.
        if (argv.len < 4) return error.InvalidArguments;

        const exe = argv[3];

        var args_list = std.ArrayList([]const u8).init(alloc);
        defer args_list.deinit();
        for (argv[4..]) |a| try args_list.append(a);

        var driver = try LLDBDriver.initLaunch(alloc, exe, args_list.items);
        defer driver.deinit();

        // Adopt regfile from env if provided so cleanup works on quit
        if (std.process.getEnvVarOwned(alloc, "DIPOLE_REGFILE") catch null) |p| {
            regs_path = p;
        }

        // 1. Wait for LLDB's initial prompt
        // 2. Set a breakpoint at main so we stop instead of exiting immediately
        try driver.sendLine("breakpoint set -n main");
        _ = try driver.readUntilPrompt(.LldbPrompt);

        // 3. Launch the program
        try driver.sendLine("run");
        const run_out = try driver.readUntilPrompt(.LldbPrompt);

        // 4. Parse the new PID
        if (extractPidFromRunOutput(run_out)) |pid| {
            driver.target_pid = pid;
        } else {
            std.debug.print("[Dipole] Error: could not detect process PID.\n", .{});
        }

        // Treat the program as stopped at the breakpoint for REPL startup
        driver.state = .Stopped;

        // Grab frame info so we show where we stopped
        try driver.sendLine("frame info");
        const frame_info = try driver.readUntilPrompt(.LldbPrompt);

        // Seed register snapshot for the right pane
        writeRegsSnapshot(&driver);

        // Continue normally
        // Seed initial output with run output + frame info
        var seeded = std.ArrayList(u8).init(alloc);
        defer seeded.deinit();
        try seeded.appendSlice(run_out);
        try seeded.appendSlice("\n");
        try seeded.appendSlice(frame_info);

        try replMode(&driver, seeded.items, alloc);

        return;
    }

    //
    // NORMAL LAUNCH (outside tmux)
    //
    if (std.mem.eql(u8, cmd, "run")) {
        if (argv.len < 3) return error.InvalidArguments;

        const exe = argv[2];

        var args_list = std.ArrayList([]const u8).init(alloc);
        defer args_list.deinit();
        for (argv[3..]) |a| try args_list.append(a);

        //
        // If tmux is available → run everything inside tmux panes
        //
        if (tmuxAvailable(alloc)) {
            try maybeBootstrapTmux(alloc, -1, dipole_path, exe);

            // Attach user to tmux session (blocking)
            var attach = std.process.Child.init(&.{ "tmux", "attach", "-t", "dipole" }, alloc);
            attach.stdin_behavior = .Inherit;
            attach.stdout_behavior = .Inherit;
            attach.stderr_behavior = .Inherit;
            try attach.spawn();
            _ = try attach.wait();
            return;
        }

        //
        // No tmux → fallback REPL
        //
        var driver = try LLDBDriver.initLaunch(alloc, exe, args_list.items);
        defer driver.deinit();

        // Set a breakpoint at main so we stop instead of running to exit
        try driver.sendLine("breakpoint set -n main");
        _ = try driver.readUntilPrompt(.LldbPrompt);

        // Launch the program
        try driver.sendLine("run");
        const run_out = try driver.readUntilPrompt(.LldbPrompt);

        try replMode(&driver, run_out, alloc);
        return;
    }

    std.debug.print("Unknown command\n", .{});
}

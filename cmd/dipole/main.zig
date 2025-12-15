const std = @import("std");
const Tui = @import("tui").Tui;
const Tmux = @import("tmux").Tmux;
const LLDBDriver = @import("lldbdriver").LLDBDriver;
const Log = @import("log");
const Args = @import("args");
const Ansi = @import("ansi");
const Panes = @import("panes");
const Term = @import("term");

const RegisterFile = @import("../../lib/core/RegisterFile.zig").RegisterFile;
const RegsViewer = @import("regsview").RegsViewer;
const REPL = @import("repl").REPL;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var args_it = try std.process.argsWithAllocator(alloc);
    defer args_it.deinit();

    const exe_path = args_it.next() orelse return error.InvalidArgs;

    // Read command
    const cmd = args_it.next() orelse {
        std.debug.print("Usage:\n", .{});
        std.debug.print("  dipole repl [--no-tmux] <pid>\n", .{});
        std.debug.print("  dipole run  [--no-tmux] <exe> [args…]\n", .{});
        std.debug.print("  dipole regs <file>\n", .{});
        return;
    };

    // -------------------------------------------------------------
    // MODE 1: regs-view (simple)
    // -------------------------------------------------------------
    if (std.mem.eql(u8, cmd, "regs")) {
        const file_path = args_it.next() orelse return error.InvalidArgs;
        try RegsViewer.run(file_path);
        return;
    }

    // -------------------------------------------------------------
    // MODE 2: repl <pid>
    // -------------------------------------------------------------
    if (std.mem.eql(u8, cmd, "repl")) {
        const a1 = args_it.next();
        const a2 = args_it.next();
        const parsed_args = try Args.parseRepl(a1, a2);

        const no_tmux = parsed_args.no_tmux;
        const pid_str = parsed_args.pid_str;

        const pid = try std.fmt.parseInt(i32, pid_str, 10);

        // Start tmux session if needed.
        if (!no_tmux) {
            try Tmux.bootstrap(alloc, exe_path, "repl", pid_str, &.{});
        }

        // Get the reg file path (set by tmux wrapper, or fallback if not bootstrapped).
        const reg_path = try Tmux.currentRegPathOwned(alloc);
        defer alloc.free(reg_path);

        // Ensure it exists even when not bootstrapped (harmless if it already exists).
        Tmux.initRegFile(reg_path);

        // Create LLDB driver
        var driver = try LLDBDriver.initAttach(alloc, pid);
        defer driver.deinit();

        _ = try driver.waitForPrompt();

        // ---------------------------
        // Break at main (optional but recommended)
        // ---------------------------
        try driver.sendLine("breakpoint set -n main");
        _ = try driver.readUntilPrompt(.LldbPrompt);

        // No "run" here — attach mode does not launch the inferior

        var tui = Tui.init(alloc);
        defer tui.deinit();
        tui.enabled = true; // or gate with env/flag later
        tui.hint_dim = no_tmux;

        // Input buffer for command line panel
        var cmd_input = std.ArrayList(u8).init(alloc);
        defer cmd_input.deinit();

        // ---------------------------------------------------------
        // MAIN REPL LOOP
        // ---------------------------------------------------------
        while (true) {
            // refresh registers before drawing
            try driver.sendLine("register read");
            const reg_out = try driver.readUntilPrompt(.LldbPrompt);
            try RegisterFile.write(reg_path, reg_out);

            if (driver.state == .Stopped) {
                try driver.sendLine("frame select 0");
                const raw_source_tmp = try driver.readUntilPrompt(.LldbPrompt);
                const raw_source = try alloc.dupe(u8, raw_source_tmp);
                defer alloc.free(raw_source);

                try driver.sendLine("thread list");
                const raw_status_tmp = try driver.readUntilPrompt(.LldbPrompt);
                const raw_status = try alloc.dupe(u8, raw_status_tmp);
                defer alloc.free(raw_status);

                // v0: regs not wired yet, keep it deterministic anyway
                const raw_regs: []const u8 = "";

                const fd = std.io.getStdOut().handle;
                const w = Term.getTerminalWidthOrNull(fd) orelse 120;
                const h = Term.getTerminalHeightOrNull(fd) orelse 40;
                _ = h;

                // pick conservative heights for now (same as you already used)
                const h_source: usize = 24;
                const h_status: usize = 3;

                const frame = try Panes.build(alloc, raw_source, raw_status, raw_regs, w, h_source, w, h_status, 0, 0);
                defer {
                    alloc.free(frame.source);
                    alloc.free(frame.status);
                    alloc.free(frame.regs);
                }

                try tui.setView(frame.source);
                try tui.setOutput(frame.status);

                // If you already have a regs setter, use it. Otherwise skip for this step.
                // try tui.setRegs(frame.regs);
            } else if (driver.state == .Exited) {
                try tui.setView("(process exited)\n");
            } else {
                // Don't overwrite Status while running/exiting; preserve REPL transcript.
                // Optionally show something only if Status is empty:
                if (tui.output().len == 0) {
                    try tui.setOutput("(running)\n");
                }
            }

            try Ansi.clearHome(std.io.getStdOut().writer());

            Log.log("Main REPL LOOP: entering tui render", .{});
            // 3. redraw entire TUI
            try tui.render(
                std.io.getStdOut().writer(),
                @tagName(driver.state),
                driver.target_pid,
                cmd_input.items,
            );
            Log.log("Main REPL LOOP: after render (about to read input)", .{});

            // 4. get user input
            cmd_input.clearRetainingCapacity();
            Log.log("REPL: about to read user input (stdin)", .{});
            const raw = try REPL.readUserInput(alloc, std.io.getStdIn().reader());
            Log.log("REPL: readUserInput returned len={} bytes", .{raw.len});

            if (raw.len > 0) {
                // Avoid logging huge lines; cap it.
                const n = @min(raw.len, 120);
                Log.log("REPL: raw[0..{}] = '{s}'", .{ n, raw[0..n] });
            } else {
                Log.log("REPL: raw is empty (EOF?)", .{});
            }

            try cmd_input.appendSlice(raw);

            // 5. parse + execute command
            const parsed = REPL.parseCommand(raw);
            Log.log("REPL: parsed command = {}", .{parsed});

            const res = try REPL.execute(
                &driver,
                parsed,
                alloc,
                reg_path,
            );
            defer if (res.out) |o| alloc.free(o);

            Log.log("REPL: execute returned keep_going={} out_len={}", .{
                res.keep_going,
                if (res.out) |o| o.len else 0,
            });

            // If the command produced output (e.g. Continue/Step/Next/Raw/Shell),
            // show it in Status.
            if (res.out) |o| {
                try tui.setOutput(o);
            }

            // clear so next render shows empty prompt
            cmd_input.clearRetainingCapacity();
            alloc.free(raw); // IMPORTANT if raw is heap allocated

            if (!res.keep_going) {
                Log.log("REPL: breaking loop (keep_going=false)", .{});
                break;
            }
        }

        return;
    }

    // -------------------------------------------------------------
    // MODE 3: run <exe> [args…]
    // -------------------------------------------------------------
    if (std.mem.eql(u8, cmd, "run")) {
        Log.log("main: just entered 'run' branch", .{});

        const a1 = args_it.next();
        const a2 = args_it.next();
        const parsed_args = try Args.parseRun(a1, a2);

        const no_tmux = parsed_args.no_tmux;
        const target_exe = parsed_args.exe;

        // If no_tmux == false, a2 may actually be the exe already consumed.
        // If no_tmux == true, a2 was the exe.
        // Either way we have consumed 1 or 2 args; now collect remaining args as before.

        // Collect remaining args
        var run_args = std.ArrayList([]const u8).init(alloc);
        defer run_args.deinit();

        while (args_it.next()) |a| {
            try run_args.append(a);
        }

        // Tmux
        Log.log("main: entering Tmux.bootstrap", .{});
        if (!no_tmux) {
            try Tmux.bootstrap(alloc, exe_path, "run", target_exe, run_args.items);
        }
        Log.log("main: returned from Tmux.bootstrap", .{});

        // Reg file path chosen by bootstrap wrapper (or fallback).
        const reg_path = try Tmux.currentRegPathOwned(alloc);
        defer alloc.free(reg_path);
        Tmux.initRegFile(reg_path);

        // Launch under lldb
        Log.log("main: calling initLaunch for exe={s}", .{target_exe});
        var driver = try LLDBDriver.initLaunch(alloc, target_exe, run_args.items);
        defer driver.deinit();
        Log.log("main: initLaunch succeeded, lldb_pid={}", .{driver.lldb_pid});

        Log.log("main: calling waitForPrompt()", .{});
        const banner = try driver.waitForPrompt();
        Log.log("main: got initial LLDB prompt, len={} bytes", .{banner.len});

        // ---------------------------
        // Break at main before running
        // ---------------------------
        Log.log("main: setting breakpoint on main()", .{});
        try driver.sendLine("breakpoint set -n main");
        var bp_out = try driver.readUntilPrompt(.LldbPrompt);
        Log.log("main: breakpoint set response len={}", .{bp_out.len});

        // ---------------------------
        // Start inferior
        // ---------------------------
        Log.log("main: sending 'run' to LLDB", .{});
        try driver.sendLine("run");
        bp_out = try driver.readUntilPrompt(.LldbPrompt);
        Log.log("main: 'run' sent successfully", .{});

        Log.log("main: in 'run' branch - breakpoint should have been set.", .{});

        // TUI
        var tui = Tui.init(alloc);
        defer tui.deinit();
        tui.enabled = true;
        tui.hint_dim = no_tmux;

        var cmd_input = std.ArrayList(u8).init(alloc);
        defer cmd_input.deinit();

        // ---------------------------------------------------------
        // MAIN REPL LOOP (same as attach mode)
        // ---------------------------------------------------------
        while (true) {
            // update registers
            try driver.sendLine("register read");
            const reg_out = try driver.readUntilPrompt(.LldbPrompt);
            try RegisterFile.write(reg_path, reg_out);

            if (driver.state == .Stopped) {
                try driver.sendLine("frame select 0");
                const raw_source_tmp = try driver.readUntilPrompt(.LldbPrompt);
                const raw_source = try alloc.dupe(u8, raw_source_tmp);
                defer alloc.free(raw_source);
                Log.log("raw_source ptr={*} len={}", .{ raw_source.ptr, raw_source.len });

                // *** start some logging
                Log.log("Main - run loop: raw_source len={} bytes", .{raw_source.len});
                if (raw_source.len > 0) {
                    const head_n = @min(raw_source.len, 800);
                    Log.log("raw_source head:\n{s}", .{raw_source[0..head_n]});

                    // show last chunk too (sometimes listing is at end)
                    const tail_n = @min(raw_source.len, 800);
                    Log.log("raw_source tail:\n{s}", .{raw_source[raw_source.len - tail_n ..]});
                }

                var it = std.mem.splitScalar(u8, raw_source, '\n');
                var shown: usize = 0;
                while (it.next()) |ln| {
                    const t = std.mem.trim(u8, ln, " \t\r");
                    if (t.len == 0) continue;
                    Log.log("raw_source line[{}] = '{s}'", .{ shown, t });
                    shown += 1;
                    if (shown >= 12) break;
                }
                // *** end some logging

                try driver.sendLine("thread list");
                const raw_status_tmp = try driver.readUntilPrompt(.LldbPrompt);
                const raw_status = try alloc.dupe(u8, raw_status_tmp);
                driver.observeThreadList(raw_status);
                defer alloc.free(raw_status);

                // v0: regs not wired yet, keep it deterministic anyway
                const raw_regs: []const u8 = "";

                const fd = std.io.getStdOut().handle;
                const w = Term.getTerminalWidthOrNull(fd) orelse 120;
                const h = Term.getTerminalHeightOrNull(fd) orelse 40;
                _ = h;

                // pick conservative heights for now (same as you already used)
                const h_source: usize = 24;
                const h_status: usize = 3;

                const frame = try Panes.build(alloc, raw_source, raw_status, raw_regs, w, h_source, w, h_status, 0, 0);
                defer {
                    alloc.free(frame.source);
                    alloc.free(frame.status);
                    alloc.free(frame.regs);
                }

                try tui.setView(frame.source);
                try tui.setOutput(frame.status);

                // If you already have a regs setter, use it. Otherwise skip for this step.
                // try tui.setRegs(frame.regs);
            } else if (driver.state == .Exited) {
                try tui.setView("(process exited)\n");
            } else {
                // Don't overwrite Status while running/exiting; preserve REPL transcript.
                // Optionally show something only if Status is empty:
                if (tui.output().len == 0) {
                    try tui.setOutput("(running)\n");
                }
            }

            try Ansi.clearHome(std.io.getStdOut().writer());

            Log.log("Main REPL LOOP: entering tui render", .{});
            try tui.render(
                std.io.getStdOut().writer(),
                @tagName(driver.state),
                driver.target_pid,
                cmd_input.items,
            );
            Log.log("Main REPL LOOP: after render (about to read input)", .{});

            cmd_input.clearRetainingCapacity();
            Log.log("REPL: about to read user input (stdin)", .{});
            const raw = try REPL.readUserInput(alloc, std.io.getStdIn().reader());
            Log.log("REPL: readUserInput returned len={} bytes", .{raw.len});

            if (raw.len > 0) {
                // Avoid logging huge lines; cap it.
                const n = @min(raw.len, 120);
                Log.log("REPL: raw[0..{}] = '{s}'", .{ n, raw[0..n] });
            } else {
                Log.log("REPL: raw is empty (EOF?)", .{});
            }

            try cmd_input.appendSlice(raw);

            const parsed = REPL.parseCommand(raw);
            Log.log("REPL: parsed command = {}", .{parsed});

            const res = try REPL.execute(
                &driver,
                parsed,
                alloc,
                reg_path,
            );
            defer if (res.out) |o| alloc.free(o);

            Log.log("REPL: execute returned keep_going={} out_len={}", .{
                res.keep_going,
                if (res.out) |o| o.len else 0,
            });

            // If the command produced output (e.g. Continue/Step/Next/Raw/Shell),
            // show it in Status.
            if (res.out) |o| {
                try tui.setOutput(o);
            }

            // clear so next render shows empty prompt
            cmd_input.clearRetainingCapacity();
            alloc.free(raw); // IMPORTANT if raw is heap allocated

            if (!res.keep_going) {
                Log.log("REPL: breaking loop (keep_going=false)", .{});
                break;
            }
        }

        return;
    }

    // -------------------------------------------------------------
    // UNKNOWN COMMAND
    // -------------------------------------------------------------
    std.debug.print("Unknown command '{s}'\n", .{cmd});
}

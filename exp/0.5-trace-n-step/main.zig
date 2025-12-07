const std = @import("std");
const Trace = @import("trace");
const LLDBDriver = @import("./lib/core/debugger/LLDBDriver.zig");

const Args = struct {
    pid: i32,
    n: usize,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try parseArgs();
    const pid = args.pid;
    const n = args.n;

    const steps = try traceNStepsBatch(allocator, pid, n);
    defer allocator.free(steps);

    var step_ct: usize = 1;
    for (steps) |step| {
        printSummary(step, step_ct);
        step_ct += 1;
    }
}

fn parseArgs() !Args {
    var args = std.process.args();
    _ = args.skip(); // skip argv[0]

    var saw_pid = false;
    var saw_n = false;
    var pid_set = false;
    var n_set = false;
    var pid: i32 = 0;
    var n: usize = 0;
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--pid")) {
            saw_pid = true;
            continue;
        }

        if (std.mem.eql(u8, arg, "--n")) {
            saw_n = true;
            continue;
        }

        if (saw_pid) {
            pid = try std.fmt.parseInt(i32, arg, 10);
            pid_set = true;
            saw_pid = false;
            continue;
        }

        if (saw_n) {
            n = try std.fmt.parseInt(usize, arg, 10);
            n_set = true;
            saw_n = false;
            continue;
        }
    }

    if (pid_set and n_set) {
        return Args{ .pid = pid, .n = n };
    }

    std.debug.print("Usage: exp-0.5-trace-n-steps --pid <PID> --n <max_steps>\n", .{});
    return error.InvalidArguments;
}

fn traceNStepsBatch(allocator: std.mem.Allocator, pid: i32, max_steps: usize) ![]Trace.TraceStep {
    var argv = std.ArrayList([]const u8).init(allocator);
    defer argv.deinit();

    try argv.append("lldb");
    try argv.append("--batch");
    try argv.append("--no-lldbinit");
    try argv.append("--source");
    try argv.append("/dev/null");

    try argv.append("-p");
    const pid_str = try std.fmt.allocPrint(allocator, "{d}", .{pid});
    defer allocator.free(pid_str);
    try argv.append(pid_str);

    // Capture initial PC
    try argv.append("--one-line");
    try argv.append("register read pc");

    // For each step: stepi + read pc (after)
    for (0..max_steps) |_| {
        try argv.append("--one-line");
        try argv.append("stepi");
        try argv.append("--one-line");
        try argv.append("register read pc");
    }

    // Detach so the target resumes
    try argv.append("--one-line");
    try argv.append("detach");

    var child = std.process.Child.init(argv.items, allocator);
    child.stdin_behavior = .Ignore;
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;

    try child.spawn();

    const stdout_file = child.stdout orelse return error.NoStdoutPipe;
    const stderr_file = child.stderr orelse return error.NoStderrPipe;
    const stdout_bytes = try stdout_file.reader().readAllAlloc(allocator, 128 * 1024);
    defer allocator.free(stdout_bytes);
    const stderr_bytes = try stderr_file.reader().readAllAlloc(allocator, 32 * 1024);
    defer allocator.free(stderr_bytes);

    const result = try child.wait();
    switch (result) {
        .Exited => |code| if (code != 0) return error.LLDBNonZeroExit,
        else => return error.LLDBFailed,
    }

    if (stderr_bytes.len > 0) {
        std.debug.print("[lldb stderr]\n{s}\n", .{stderr_bytes});
    }

    std.debug.print("[lldb stdout]\n{s}\n", .{stdout_bytes});

    const pcs = try parsePcLines(allocator, stdout_bytes);
    defer allocator.free(pcs);
    if (pcs.len < max_steps + 1) {
        std.debug.print("[dipole] parsed {d} pc values, need {d}\n", .{ pcs.len, max_steps + 1 });
        return error.FailedToFindTwoPCs;
    }

    var steps = std.ArrayList(Trace.TraceStep).init(allocator);
    for (0..max_steps) |i| {
        const before_pc = pcs[i];
        const after_pc = pcs[i + 1];
        const ts_before: Trace.TraceSnapshot = .{
            .pc = before_pc,
            .timestamp_ns = std.time.nanoTimestamp(),
        };
        const ts_after: Trace.TraceSnapshot = .{
            .pc = after_pc,
            .timestamp_ns = std.time.nanoTimestamp(),
        };
        try steps.append(.{ .before = ts_before, .after = ts_after });
    }

    return steps.toOwnedSlice();
}

fn parsePcLines(allocator: std.mem.Allocator, output: []const u8) ![]usize {
    var list = std.ArrayList(usize).init(allocator);

    var it = std.mem.splitScalar(u8, output, '\n');
    while (it.next()) |line| {
        // Only consider lines that contain the marker
        if (std.mem.containsAtLeast(u8, line, 1, "pc = 0x")) {
            // Reuse the existing tested parser from LLDBDriver
            const pc = LLDBDriver.Driver.parsePc(line) catch |err| {
                // If parsePc fails (rare), skip this line instead of aborting
                if (err == error.PcNotFound) continue;
                return err;
            };

            try list.append(pc);
        }
    }
    return list.toOwnedSlice();
}

fn printSummary(step: Trace.TraceStep, step_ct: usize) void {
    if (step_ct == 1) {
        std.debug.print("\n=== Dipole exp 0.5 — mutli step trace ===\n", .{});
    }

    std.debug.print("Step {d} ...\n", .{step_ct});

    const delta = step.pcDeltaBytes();

    std.debug.print("pc_before : 0x{x}\n", .{step.before.pc});
    std.debug.print("pc_after  : 0x{x}\n", .{step.after.pc});
    std.debug.print("delta     : {d} bytes\n", .{delta});

    const dt_ns = @as(i128, step.after.timestamp_ns) - @as(i128, step.before.timestamp_ns);
    std.debug.print("time delta: {d} ns (approx)\n", .{dt_ns});

    if (delta > 0) {
        std.debug.print("note      : pc advanced forward in memory → likely next instruction.\n", .{});
    } else if (delta < 0) {
        std.debug.print("note      : pc moved backwards → possible jump or branch.\n", .{});
    } else {
        std.debug.print("note      : pc unchanged → perhaps a trap, breakpoint, or same instruction re-executed.\n", .{});
    }
    std.debug.print("==========================================\n\n", .{});
}

const std = @import("std");
const Trace = @import("trace");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const pid = try parsePidFromArgs();
    const trace_step = try runOneStepTrace(allocator, pid);

    printSummary(trace_step);
}

fn parsePidFromArgs() !i32 {
    var args = std.process.args();
    _ = args.skip(); // skip argv[0]

    var saw_pid_flag = false;
    while (args.next()) |arg| {
        if (!saw_pid_flag and std.mem.eql(u8, arg, "--pid")) {
            saw_pid_flag = true;
            continue;
        }

        if (saw_pid_flag) {
            // convert arg -> i32
            const parsed = try std.fmt.parseInt(i32, arg, 10);
            return parsed;
        }
    }

    std.debug.print("Usage: exp-0.4-trace-step --pid <PID>\n", .{});
    return error.MissingPid;
}

fn runOneStepTrace(allocator: std.mem.Allocator, pid: i32) !Trace.TraceStep {
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

    try argv.append("--one-line");
    try argv.append("register read pc");

    try argv.append("--one-line");
    try argv.append("stepi");

    try argv.append("--one-line");
    try argv.append("register read pc");

    var child = std.process.Child.init(argv.items, allocator);
    child.stdin_behavior = .Ignore;
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;

    try child.spawn();

    // Read stdout
    const stdout_file = child.stdout orelse return error.NoStdoutPipe;
    var stdout_reader = stdout_file.reader();
    const stdout_bytes = try stdout_reader.readAllAlloc(allocator, 64 * 1024);
    defer allocator.free(stdout_bytes);

    // Read stderr
    const stderr_file = child.stderr orelse return error.NoStderrPipe;
    var stderr_reader = stderr_file.reader();
    const stderr_bytes = try stderr_reader.readAllAlloc(allocator, 16 * 1024);
    defer allocator.free(stderr_bytes);

    if (stderr_bytes.len > 0) {
        // For now we just print; later you might structure this.
        std.debug.print("lldb stderr:\n{s}\n", .{stderr_bytes});
    }

    const result = try child.wait();
    switch (result) {
        .Exited => |code| {
            if (code != 0) {
                return error.LLDBNonZeroExit;
            }
        },
        else => return error.LLDBFailed,
    }

    // Parse two PCs from stdout
    const pcs = try parseTwoPcs(stdout_bytes);

    var now = std.time.nanoTimestamp();
    const ts_before: Trace.TraceSnapshot = .{
        .pc = pcs[0],
        .timestamp_ns = now,
    };

    // For this experiment, we don’t measure real elapsed time,
    // we just call `now` again; later you can refine this.
    now = std.time.nanoTimestamp();
    const ts_after: Trace.TraceSnapshot = .{
        .pc = pcs[1],
        .timestamp_ns = now,
    };

    return Trace.TraceStep{
        .before = ts_before,
        .after = ts_after,
    };
}

fn parseTwoPcs(stdout_bytes: []const u8) ![2]usize {
    var it = std.mem.tokenizeScalar(u8, stdout_bytes, '\n');
    var found: [2]usize = .{ 0, 0 };
    var idx: usize = 0;

    while (it.next()) |line| {
        // Typical lldb line: "    pc = 0x0000000100003f44"
        if (std.mem.indexOf(u8, line, "pc =")) |pos| {
            // Extract substring after '='
            const after_eq = std.mem.trim(u8, line[pos + 4 ..], " \t");
            // LLDB appends symbol info after the address; take only the first token.
            var tokens = std.mem.tokenizeAny(u8, after_eq, " \t");
            const pc_tok = tokens.next() orelse continue;
            const pc_val = try std.fmt.parseInt(usize, pc_tok, 0);
            if (idx < 2) {
                found[idx] = pc_val;
                idx += 1;
            } else break;
        }
    }

    if (idx != 2) return error.FailedToFindTwoPCs;

    return found;
}

fn printSummary(step: Trace.TraceStep) void {
    const delta = step.pcDeltaBytes();

    std.debug.print("\n=== Dipole exp 0.4 — single step trace ===\n", .{});
    std.debug.print("pc_before : 0x{x}\n", .{step.before.pc});
    std.debug.print("pc_after  : 0x{x}\n", .{step.after.pc});
    std.debug.print("delta     : {d} bytes\n", .{delta});

    const dt_ns = @as(i128, step.after.timestamp_ns) - @as(i128, step.before.timestamp_ns);
    std.debug.print("time delta: {d} ns (approx)\n", .{dt_ns});

    // Tiny bit of pedagogy:
    if (delta > 0) {
        std.debug.print("note      : pc advanced forward in memory → likely next instruction.\n", .{});
    } else if (delta < 0) {
        std.debug.print("note      : pc moved backwards → possible jump or branch.\n", .{});
    } else {
        std.debug.print("note      : pc unchanged → perhaps a trap, breakpoint, or same instruction re-executed.\n", .{});
    }
    std.debug.print("==========================================\n\n", .{});
}

const std = @import("std");

fn checkpoint(msg: []const u8) void {
    std.debug.print("[smoke] {s}\n", .{msg});
}

fn dumpAndFail(err: anyerror, stdout: []const u8, stderr: []const u8) anyerror {
    std.debug.print(
        "\n[smoke] ASSERTION FAILED: {}\n\n--- stdout ---\n{s}\n\n--- stderr ---\n{s}\n",
        .{ err, stdout, stderr },
    );
    return err;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var it = try std.process.argsWithAllocator(alloc);
    defer it.deinit();
    _ = it.next(); // smoke exe

    const dipole_path = it.next() orelse return error.MissingDipolePath;
    const target_path = it.next() orelse return error.MissingTargetPath;

    checkpoint("starting dipole --no-tmux simple");

    var child = std.process.Child.init(
        &.{ dipole_path, "run", "--no-tmux", target_path },
        alloc,
    );
    child.stdin_behavior = .Pipe;
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;

    try child.spawn();

    checkpoint("dipole launched, sending commands: s; q");

    // Script: step once, then quit.
    // (If your REPL expects "s" and "q", this matches your manual flow.)
    try child.stdin.?.writer().writeAll("s\nq\n");
    child.stdin.?.close();
    child.stdin = null;

    checkpoint("commands sent, collecting output");

    // Collect output
    const stdout = try child.stdout.?.reader().readAllAlloc(alloc, 1 << 20);
    defer alloc.free(stdout);

    const stderr = try child.stderr.?.reader().readAllAlloc(alloc, 1 << 20);
    defer alloc.free(stderr);

    checkpoint("dipole exited, validating output");

    const term = try child.wait();
    if (term != .Exited or term.Exited != 0) {
        std.debug.print("Smoke failed.\nstdout:\n{s}\n\nstderr:\n{s}\n", .{ stdout, stderr });
        return error.SmokeFailed;
    }

    checkpoint("checking: stop reason reported");
    // Some Dipole output may go to stderr (e.g. std.debug.print), so check both.
    if (std.mem.indexOf(u8, stdout, "stop reason") == null and
        std.mem.indexOf(u8, stderr, "stop reason") == null)
    {
        return dumpAndFail(error.NoStopReason, stdout, stderr);
    }

    checkpoint("checking: breakpoint at main hit");
    if (std.mem.indexOf(u8, stdout, "breakpoint") == null and
        std.mem.indexOf(u8, stderr, "breakpoint") == null)
    {
        return dumpAndFail(error.NoBreakpointHit, stdout, stderr);
    }

    checkpoint("checking: step occurred");
    if (std.mem.indexOf(u8, stdout, "step") == null and
        std.mem.indexOf(u8, stderr, "step") == null)
    {
        return dumpAndFail(error.NoStepObserved, stdout, stderr);
    }

    checkpoint("basic interaction OK");
}

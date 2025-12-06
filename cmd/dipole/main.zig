const std = @import("std");

fn getUserName(allocator: std.mem.Allocator) ![]const u8 {
    var env = try std.process.getEnvMap(allocator);
    defer env.deinit();

    const val = env.get("USER") orelse "unknown";

    if (std.mem.eql(u8, val, "unknown")) {
        // static string literal, no need to free
        return val;
    }

    // copy into allocator-owned memory that outlives env.deinit()
    return try allocator.dupe(u8, val);
}

fn pickPidInteractive(allocator: std.mem.Allocator) !i32 {
    var cmd = std.ArrayList([]const u8).init(allocator);
    defer cmd.deinit();

    const user = try getUserName(allocator);
    // Only the real username is heap-allocated; "unknown" is a static literal.
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

    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();

    if (child.stdout) |pipe| {
        var reader = pipe.reader();
        var tmp: [1024]u8 = undefined;

        while (true) {
            const n = try reader.read(&tmp);
            if (n == 0) break;
            try buf.appendSlice(tmp[0..n]);
        }
    }

    _ = try child.wait();

    // iterate ps output lines
    var iter = std.mem.splitScalar(u8, buf.items, '\n');
    while (iter.next()) |line| {
        if (line.len == 0) continue;
        if (std.mem.indexOf(u8, line, "??") != null) continue;
        try std.io.getStdOut().writer().print("{s}\n", .{line});
    }

    // Prompt user for PID
    std.debug.print(
        "\n[Dipole] Enter PID to attach (empty to cancel): ",
        .{},
    );

    var stdin_reader = std.io.getStdIn().reader();
    var buf_in: [64]u8 = undefined;

    const maybe_line = try stdin_reader.readUntilDelimiterOrEof(&buf_in, '\n');
    const line = maybe_line orelse return error.InvalidArguments;

    const trimmed = std.mem.trim(u8, line, " \t\r\n");
    if (trimmed.len == 0) return error.InvalidArguments;

    const pid = try std.fmt.parseInt(i32, trimmed, 10);
    return pid;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    var attach_cmd: ?[]u8 = null;

    var args_it = std.process.args();
    _ = args_it.next();

    var attach_mode = false;
    var pid: i32 = 0;

    const first = args_it.next() orelse {
        std.debug.print("Usage: dipole-play <path-to-target> | --pid [pid]\n", .{});
        return error.InvalidArguments;
    };

    var target: []const u8 = first;

    if (std.mem.eql(u8, first, "--pid")) {
        if (args_it.next()) |pid_arg| {
            // Case 1: `--pid 1234`
            pid = try std.fmt.parseInt(i32, pid_arg, 10);
            attach_mode = true;
        } else {
            // Case 2: `--pid` with no PID → process picker
            pid = try pickPidInteractive(allocator);
            attach_mode = true;
        }
    } else {
        // Launch mode: first arg is the binary path
        target = first;
    }

    var cmd = std.ArrayList([]const u8).init(allocator);
    defer cmd.deinit();

    try cmd.append("lldb");
    try cmd.append("-b");

    if (attach_mode) {
        try cmd.append("-o");
        attach_cmd = try std.fmt.allocPrint(allocator, "attach --pid {d}", .{pid});
        try cmd.append(attach_cmd.?);
        try cmd.append("-o");
        try cmd.append("bt");
    } else {
        try cmd.append("-o");
        try cmd.append("breakpoint set -n main");
        try cmd.append("-o");
        try cmd.append("run");
        try cmd.append("-o");
        try cmd.append("bt");
        try cmd.append("--");
        try cmd.append(target);
    }

    var child = std.process.Child.init(cmd.items, allocator);
    child.stdin_behavior = .Inherit;
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    //child.stdout_behavior = .Inherit;
    //child.stderr_behavior = .Inherit;

    try child.spawn();

    // now LLDB has copied argv internally; we can free the string
    if (attach_cmd) |ac| {
        allocator.free(ac);
    }

    var child_output = std.ArrayList(u8).init(allocator);
    defer child_output.deinit();

    if (child.stdout) |stdout_pipe| {
        var reader = stdout_pipe.reader();
        var buf: [4096]u8 = undefined;
        while (true) {
            const n = try reader.read(&buf);
            if (n == 0) break;
            const slice = buf[0..n];
            try std.io.getStdOut().writer().writeAll(slice);
            try child_output.appendSlice(slice);
        }
    }

    const term = try child.wait();

    var iter = std.mem.splitScalar(u8, child_output.items, '\n');
    var user_frames = std.ArrayList([]const u8).init(allocator);
    defer user_frames.deinit();
    var system_frames = std.ArrayList([]const u8).init(allocator);
    defer system_frames.deinit();

    const frame_tag = "frame #";
    while (iter.next()) |line| {
        if (std.mem.indexOf(u8, line, frame_tag) != null) {
            if (std.mem.indexOf(u8, line, "dyld`") != null) {
                try system_frames.append(line);
            } else {
                try user_frames.append(line);
            }
        }
    }

    std.debug.print("\n[Dipole] lldb exited with {any}\n", .{term});

    std.debug.print("\n[Dipole] Summary\n", .{});

    if (attach_mode) {
        std.debug.print("[Dipole] Attached to PID: {d}\n", .{pid});
    }

    if (user_frames.items.len > 0) {
        std.debug.print("[Dipole] Top frame:\n  {s}\n", .{user_frames.items[0]});
    }

    std.debug.print("[Dipole] User frames: {d}\n", .{user_frames.items.len});
    std.debug.print("[Dipole] System frames hidden: {d}\n", .{system_frames.items.len});
}

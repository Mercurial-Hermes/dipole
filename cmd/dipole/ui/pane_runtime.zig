// cmd/dipole/ui/pane/runtime.zig

const std = @import("std");
const request_envelope = @import("request_envelope");

pub const PaneRole = enum {
    repl,
    output,
};

pub const ReplAction = union(enum) {
    command: []u8,
    quit,
};

pub fn parsePaneRole(token: []const u8) ?PaneRole {
    if (std.mem.eql(u8, token, "repl")) return .repl;
    if (std.mem.eql(u8, token, "output")) return .output;
    return null;
}

fn roleBanner(role: PaneRole) []const u8 {
    return switch (role) {
        .repl => "",
        .output => "[dipole view pane]\n",
    };
}

pub fn runPane(
    allocator: std.mem.Allocator,
    cmd_fd: std.posix.fd_t,
    out_fd: std.posix.fd_t,
    source_id: u32,
    role: PaneRole,
    sink_file: ?std.fs.File,
) !void {
    var buf: [1024]u8 = undefined;
    var line_buf = std.ArrayList(u8).init(allocator);
    defer line_buf.deinit();
    const stdout = std.io.getStdOut().writer();
    const sink_writer = if (sink_file) |file| file.writer() else null;
    const read_stdin = role == .repl;
    const read_output = (role == .repl and sink_file != null and out_fd >= 0) or
        (role == .output and out_fd >= 0);
    const banner = roleBanner(role);
    if (banner.len > 0) {
        try stdout.writeAll(banner);
        if (sink_writer) |writer| {
            try writer.writeAll(banner);
        }
    }
    while (true) {
        if (!read_stdin and !read_output) {
            std.time.sleep(1 * std.time.ns_per_s);
            continue;
        }
        var fds = [_]std.posix.pollfd{
            .{ .fd = if (read_stdin) std.posix.STDIN_FILENO else -1, .events = std.posix.POLL.IN, .revents = 0 },
            .{ .fd = if (read_output) out_fd else -1, .events = std.posix.POLL.IN, .revents = 0 },
        };
        _ = try std.posix.poll(&fds, -1);
        if (read_stdin and fds[0].revents & std.posix.POLL.IN != 0) {
            const n = std.posix.read(std.posix.STDIN_FILENO, &buf) catch |err| switch (err) {
                error.WouldBlock => 0,
                else => return err,
            };
            if (n == 0) {
                if (cmd_fd >= 0) {
                    _ = std.posix.close(cmd_fd);
                }
                return;
            }
            try line_buf.appendSlice(buf[0..n]);
            while (std.mem.indexOfScalar(u8, line_buf.items, '\n')) |idx| {
                const line = std.mem.trim(u8, line_buf.items[0..idx], " \t\r");
                const action = try parseReplLine(allocator, line);
                if (action) |act| switch (act) {
                    .quit => {
                        if (cmd_fd >= 0) {
                            _ = std.posix.close(cmd_fd);
                        }
                        return;
                    },
                    .command => |cmd| {
                        defer allocator.free(cmd);
                        try request_envelope.writeEnvelope(cmd_fd, source_id, cmd);
                    },
                };
                if (idx + 1 >= line_buf.items.len) {
                    line_buf.clearRetainingCapacity();
                    break;
                }
                std.mem.copyForwards(u8, line_buf.items[0..], line_buf.items[idx + 1 ..]);
                line_buf.items.len -= idx + 1;
            }
        }
        if (read_output and fds[1].revents & std.posix.POLL.IN != 0) {
            const n = std.posix.read(out_fd, &buf) catch |err| switch (err) {
                error.WouldBlock => 0,
                else => return err,
            };
            if (n == 0) return;
            if (role == .output) {
                try stdout.writeAll(buf[0..n]);
            } else if (sink_writer) |writer| {
                try writer.writeAll(buf[0..n]);
            }
        }
    }
}

pub fn parseReplLine(
    allocator: std.mem.Allocator,
    line: []const u8,
) !?ReplAction {
    if (line.len == 0) return null;
    var it = std.mem.tokenizeScalar(u8, line, ' ');
    const verb = it.next() orelse return null;
    if (std.mem.eql(u8, verb, "q") or std.mem.eql(u8, verb, "quit")) {
        return .quit;
    }
    if (std.mem.eql(u8, verb, "step") or std.mem.eql(u8, verb, "step-in")) {
        const cmd = try allocator.dupe(u8, "thread step-in\n");
        return .{ .command = cmd };
    }
    if (std.mem.eql(u8, verb, "next") or std.mem.eql(u8, verb, "step-over")) {
        const cmd = try allocator.dupe(u8, "thread step-over\n");
        return .{ .command = cmd };
    }
    if (std.mem.eql(u8, verb, "continue") or std.mem.eql(u8, verb, "c")) {
        const cmd = try allocator.dupe(u8, "process continue\n");
        return .{ .command = cmd };
    }
    if (std.mem.eql(u8, verb, "b") or std.mem.eql(u8, verb, "breakpoint")) {
        const arg0 = it.next() orelse return null;
        const arg = if (std.mem.eql(u8, arg0, "set")) (it.next() orelse return null) else arg0;
        const colon = std.mem.indexOfScalar(u8, arg, ':') orelse return null;
        const file = arg[0..colon];
        const line_str = arg[colon + 1 ..];
        if (file.len == 0 or line_str.len == 0) return null;
        const line_num = std.fmt.parseInt(u32, line_str, 10) catch return null;
        const cmd = try std.fmt.allocPrint(
            allocator,
            "breakpoint set --file {s} --line {d}\n",
            .{ file, line_num },
        );
        return .{ .command = cmd };
    }
    return null;
}

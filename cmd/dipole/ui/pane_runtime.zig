const std = @import("std");
const request_envelope = @import("request_envelope");

pub const PaneRole = enum {
    repl,
    output,
};

pub fn parsePaneRole(token: []const u8) ?PaneRole {
    if (std.mem.eql(u8, token, "repl")) return .repl;
    if (std.mem.eql(u8, token, "output")) return .output;
    return null;
}

fn roleBanner(role: PaneRole) []const u8 {
    return switch (role) {
        .repl => "",
        .output => "[dipole output pane]\n",
    };
}

pub fn runPane(
    cmd_fd: std.posix.fd_t,
    out_fd: std.posix.fd_t,
    source_id: u32,
    role: PaneRole,
    sink_file: ?std.fs.File,
) !void {
    var buf: [1024]u8 = undefined;
    const stdout = std.io.getStdOut().writer();
    const sink_writer = if (sink_file) |file| file.writer() else null;
    var fds = [_]std.posix.pollfd{
        .{ .fd = std.posix.STDIN_FILENO, .events = std.posix.POLL.IN, .revents = 0 },
        .{ .fd = out_fd, .events = std.posix.POLL.IN, .revents = 0 },
    };
    const banner = roleBanner(role);
    if (banner.len > 0) {
        try stdout.writeAll(banner);
        if (sink_writer) |writer| {
            try writer.writeAll(banner);
        }
    }
    while (true) {
        fds[0].revents = 0;
        fds[1].revents = 0;
        _ = try std.posix.poll(&fds, -1);
        if (fds[0].revents & std.posix.POLL.IN != 0) {
            const n = std.posix.read(std.posix.STDIN_FILENO, &buf) catch |err| switch (err) {
                error.WouldBlock => 0,
                else => return err,
            };
            if (n == 0) {
                _ = std.posix.close(cmd_fd);
            } else {
                try request_envelope.writeEnvelope(cmd_fd, source_id, buf[0..n]);
            }
        }
        if (fds[1].revents & std.posix.POLL.IN != 0) {
            const n = std.posix.read(out_fd, &buf) catch |err| switch (err) {
                error.WouldBlock => 0,
                else => return err,
            };
            if (n == 0) break;
            try stdout.writeAll(buf[0..n]);
            if (sink_writer) |writer| {
                try writer.writeAll(buf[0..n]);
            }
        }
    }
}

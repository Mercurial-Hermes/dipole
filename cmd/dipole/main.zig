const std = @import("std");
const semantic_list = @import("semantic_list");
const semantic_show = @import("semantic_show");
const semantic_eval = @import("semantic_eval");
const semantic_render = @import("semantic_render");
const lldb_launcher = @import("lldb_launcher");
const pty_raw_driver = @import("pty_raw_driver");

const Usage = enum { top, list, show, eval, render, attach };

fn printUsage(w: anytype, which: Usage) !void {
    switch (which) {
        .top => try w.writeAll(
            "usage:\n" ++
                "  dipole semantic (list|show <projection@version>|eval <projection@version> --log <path>|render <projection@version> --log <path>)\n" ++
                "  dipole attach --pid <pid>\n" ++
                "  dipole interrupt\n" ++
                "  dipole continue\n" ++
                "  dipole detach\n",
        ),
        .list => try w.writeAll("usage: dipole semantic list\n"),
        .show => try w.writeAll("usage: dipole semantic show <projection@version>\n"),
        .eval => try w.writeAll("usage: dipole semantic eval <projection@version> --log <path>\n"),
        .render => try w.writeAll("usage: dipole semantic render <projection@version> --log <path>\n"),
        .attach => try w.writeAll("usage: dipole attach --pid <pid>\n"),
    }
}

fn dieToken(w: anytype, token: []const u8, code: u8) noreturn {
    w.writeAll(token) catch {};
    w.writeByte('\n') catch {};
    std.process.exit(code);
}

const SessionCommand = enum { interrupt, @"continue", detach };

const Session = struct {
    launcher: lldb_launcher.LLDBLauncher,
    driver: pty_raw_driver.PtyRawDriver,
};

fn drainOutput(session: *Session, out: anytype) !void {
    while (pty_raw_driver.PtyRawDriver.poll(@ptrCast(&session.driver))) |obs| {
        switch (obs) {
            .rx => |bytes| {
                defer session.driver.allocator.free(bytes);
                if (bytes.len > 0) {
                    try out.writeAll(bytes);
                }
            },
            else => {},
        }
    }
}

fn sendLine(session: *Session, line: []const u8, out: anytype) !void {
    try pty_raw_driver.PtyRawDriver.send(@ptrCast(&session.driver), line);
    try drainOutput(session, out);
}

fn parseSessionCommand(token: []const u8) ?SessionCommand {
    if (std.mem.eql(u8, token, "interrupt")) return .interrupt;
    if (std.mem.eql(u8, token, "continue")) return .@"continue";
    if (std.mem.eql(u8, token, "detach")) return .detach;
    return null;
}

fn runSessionCommands(
    session: *Session,
    args_iter: *std.process.ArgIterator,
    stdin: anytype,
    stdout: anytype,
) !void {
    var saw_any = false;
    while (args_iter.next()) |token| {
        saw_any = true;
        const cmd = parseSessionCommand(token) orelse {
            return error.InvalidSessionCommand;
        };

        switch (cmd) {
            .interrupt => try sendLine(session, "process interrupt\n", stdout),
            .@"continue" => try sendLine(session, "process continue\n", stdout),
            .detach => {
                try sendLine(session, "detach\n", stdout);
                return;
            },
        }
    }

    if (!saw_any) {
        var line_buf: [256]u8 = undefined;
        while (true) {
            const line = (try stdin.readUntilDelimiterOrEof(&line_buf, '\n')) orelse break;
            if (line.len == 0) continue;
            const cmd = parseSessionCommand(line) orelse continue;
            switch (cmd) {
                .interrupt => try sendLine(session, "process interrupt\n", stdout),
                .@"continue" => try sendLine(session, "process continue\n", stdout),
                .detach => {
                    try sendLine(session, "detach\n", stdout);
                    return;
                },
            }
        }
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var args_iter = try std.process.argsWithAllocator(alloc);
    defer args_iter.deinit();
    _ = args_iter.next(); // skip argv[0]

    const stderr = std.io.getStdErr().writer();
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    const domain = args_iter.next() orelse {
        try printUsage(stderr, .top);
        std.process.exit(2);
    };
    if (!std.mem.eql(u8, domain, "semantic")) {
        if (std.mem.eql(u8, domain, "attach")) {
            const flag = args_iter.next() orelse {
                try printUsage(stderr, .attach);
                std.process.exit(2);
            };
            if (!std.mem.eql(u8, flag, "--pid")) {
                try printUsage(stderr, .attach);
                std.process.exit(2);
            }
            const pid_str = args_iter.next() orelse {
                try printUsage(stderr, .attach);
                std.process.exit(2);
            };
            const pid = std.fmt.parseInt(i32, pid_str, 10) catch {
                try printUsage(stderr, .attach);
                std.process.exit(2);
            };

            const launcher = try lldb_launcher.LLDBLauncher.attach(pid);
            var session = Session{
                .launcher = launcher,
                .driver = pty_raw_driver.PtyRawDriver.init(alloc, launcher.master_fd),
            };
            defer {
                _ = session.launcher.shutdown() catch {};
                session.driver.master_fd = -1;
                session.driver.deinit();
            }

            try drainOutput(&session, stdout);

            runSessionCommands(&session, &args_iter, stdin, stdout) catch |err| switch (err) {
                error.InvalidSessionCommand => {
                    try printUsage(stderr, .top);
                    std.process.exit(2);
                },
                else => return err,
            };

            return;
        }

        if (std.mem.eql(u8, domain, "interrupt") or std.mem.eql(u8, domain, "continue") or std.mem.eql(u8, domain, "detach")) {
            try printUsage(stderr, .top);
            std.process.exit(2);
        }

        try printUsage(stderr, .top);
        std.process.exit(2);
    }

    const subcmd = args_iter.next() orelse {
        try printUsage(stderr, .top);
        std.process.exit(2);
    };

    if (std.mem.eql(u8, subcmd, "list")) {
        if (args_iter.next() != null) {
            try printUsage(stderr, .list);
            std.process.exit(2);
        }

        const json = try semantic_list.listProjections(alloc);
        defer alloc.free(json);

        try stdout.writeAll(json);
        return;
    }

    if (std.mem.eql(u8, subcmd, "show")) {
        const selector = args_iter.next() orelse {
            try printUsage(stderr, .show);
            std.process.exit(2);
        };
        if (args_iter.next() != null) {
            try printUsage(stderr, .show);
            std.process.exit(2);
        }

        const bytes = semantic_show.run(alloc, selector) catch |err| {
            if (semantic_show.errorInfo(err)) |info| {
                dieToken(stderr, info.token, info.exit_code);
            }
            dieToken(stderr, "ERR_SHOW_FAILED", 1);
        };
        defer alloc.free(bytes);
        try stdout.writeAll(bytes);
        return;
    }

    if (std.mem.eql(u8, subcmd, "eval")) {
        const selector = args_iter.next() orelse {
            try printUsage(stderr, .eval);
            std.process.exit(2);
        };
        const flag = args_iter.next() orelse {
            try printUsage(stderr, .eval);
            std.process.exit(2);
        };
        if (!std.mem.eql(u8, flag, "--log")) {
            try printUsage(stderr, .eval);
            std.process.exit(2);
        }
        const log_path = args_iter.next() orelse {
            try printUsage(stderr, .eval);
            std.process.exit(2);
        };
        if (args_iter.next() != null) {
            try printUsage(stderr, .eval);
            std.process.exit(2);
        }

        const bytes = semantic_eval.eval(alloc, selector, log_path) catch |err| {
            if (semantic_eval.errorInfo(err)) |info| {
                dieToken(stderr, info.token, info.exit_code);
            }
            dieToken(stderr, "ERR_EVAL_FAILED", 1);
        };
        defer alloc.free(bytes);

        try stdout.writeAll(bytes);
        return;
    }

    if (std.mem.eql(u8, subcmd, "render")) {
        const selector = args_iter.next() orelse {
            try printUsage(stderr, .eval);
            std.process.exit(2);
        };
        const flag = args_iter.next() orelse {
            try printUsage(stderr, .eval);
            std.process.exit(2);
        };
        if (!std.mem.eql(u8, flag, "--log")) {
            try printUsage(stderr, .eval);
            std.process.exit(2);
        }
        const log_path = args_iter.next() orelse {
            try printUsage(stderr, .eval);
            std.process.exit(2);
        };
        if (args_iter.next() != null) {
            try printUsage(stderr, .eval);
            std.process.exit(2);
        }

        const bytes = semantic_render.render(alloc, selector, log_path) catch |err| {
            if (semantic_render.errorInfo(err)) |info| {
                dieToken(stderr, info.token, info.exit_code);
            }
            dieToken(stderr, "ERR_RENDER_FAILED", 1);
        };
        defer alloc.free(bytes);

        try stdout.writeAll(bytes);
        return;
    }

    try printUsage(stderr, .top);
    std.process.exit(2);
}

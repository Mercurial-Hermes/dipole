const std = @import("std");
const semantic_list = @import("semantic_list");
const semantic_show = @import("semantic_show");
const semantic_eval = @import("semantic_eval");
const semantic_render = @import("semantic_render");
const attach_session = @import("attach_session");

const Usage = enum { top, list, show, eval, render, attach };

fn printUsage(w: anytype, which: Usage) !void {
    switch (which) {
        .top => try w.writeAll(
            "usage:\n" ++
                "  dipole semantic (list|show <projection@version>|eval <projection@version> --log <path>|render <projection@version> --log <path>)\n" ++
                "  dipole attach --pid <pid> [--tmux]\n" ++
                "  dipole interrupt\n" ++
                "  dipole continue\n" ++
                "  dipole detach\n",
        ),
        .list => try w.writeAll("usage: dipole semantic list\n"),
        .show => try w.writeAll("usage: dipole semantic show <projection@version>\n"),
        .eval => try w.writeAll("usage: dipole semantic eval <projection@version> --log <path>\n"),
        .render => try w.writeAll("usage: dipole semantic render <projection@version> --log <path>\n"),
        .attach => try w.writeAll("usage: dipole attach --pid <pid> [--tmux]\n"),
    }
}

fn dieToken(w: anytype, token: []const u8, code: u8) noreturn {
    w.writeAll(token) catch {};
    w.writeByte('\n') catch {};
    std.process.exit(code);
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

            attach_session.runAttach(alloc, pid, &args_iter, stdin) catch |err| switch (err) {
                error.InvalidSessionCommand => {
                    try printUsage(stderr, .top);
                    std.process.exit(2);
                },
                else => return err,
            };

            return;
        }

        if (std.mem.eql(u8, domain, "attach-pane")) {
            var cmd_fd: ?std.posix.fd_t = null;
            var out_fd: ?std.posix.fd_t = null;
            var source_id: ?u32 = null;
            var pane_role: ?attach_session.PaneRole = null;

            while (args_iter.next()) |flag| {
                if (std.mem.eql(u8, flag, "--cmd-fd")) {
                    const value = args_iter.next() orelse {
                        try printUsage(stderr, .top);
                        std.process.exit(2);
                    };
                    cmd_fd = std.fmt.parseInt(std.posix.fd_t, value, 10) catch {
                        try printUsage(stderr, .top);
                        std.process.exit(2);
                    };
                    continue;
                }
                if (std.mem.eql(u8, flag, "--out-fd")) {
                    const value = args_iter.next() orelse {
                        try printUsage(stderr, .top);
                        std.process.exit(2);
                    };
                    out_fd = std.fmt.parseInt(std.posix.fd_t, value, 10) catch {
                        try printUsage(stderr, .top);
                        std.process.exit(2);
                    };
                    continue;
                }
                if (std.mem.eql(u8, flag, "--source-id")) {
                    const value = args_iter.next() orelse {
                        try printUsage(stderr, .top);
                        std.process.exit(2);
                    };
                    source_id = std.fmt.parseInt(u32, value, 10) catch {
                        try printUsage(stderr, .top);
                        std.process.exit(2);
                    };
                    continue;
                }
                if (std.mem.eql(u8, flag, "--pane-role")) {
                    const value = args_iter.next() orelse {
                        try printUsage(stderr, .top);
                        std.process.exit(2);
                    };
                    pane_role = attach_session.parsePaneRole(value) orelse {
                        try printUsage(stderr, .top);
                        std.process.exit(2);
                    };
                    continue;
                }
                try printUsage(stderr, .top);
                std.process.exit(2);
            }

            if (cmd_fd == null or out_fd == null or source_id == null or pane_role == null) {
                try printUsage(stderr, .top);
                std.process.exit(2);
            }

            try attach_session.runAttachPane(cmd_fd.?, out_fd.?, source_id.?, pane_role.?);
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

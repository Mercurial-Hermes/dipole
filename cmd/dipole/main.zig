const std = @import("std");
const semantic_list = @import("semantic_list");
const semantic_show = @import("semantic_show");
const semantic_eval = @import("semantic_eval");
const semantic_render = @import("semantic_render");

const Usage = enum { top, list, show, eval, render };

fn printUsage(w: anytype, which: Usage) !void {
    switch (which) {
        .top => try w.writeAll("usage: dipole semantic (list|show <projection@version>)\n"),
        .list => try w.writeAll("usage: dipole semantic list\n"),
        .show => try w.writeAll("usage: dipole semantic show <projection@version>\n"),
        .eval => try w.writeAll("usage: dipole semantic eval <projection@version> --log <path>\n"),
        .render => try w.writeAll("usage: dipole semantic render <projection@version> --log <path>\n"),
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

    const domain = args_iter.next() orelse {
        try printUsage(stderr, .top);
        std.process.exit(2);
    };
    if (!std.mem.eql(u8, domain, "semantic")) {
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

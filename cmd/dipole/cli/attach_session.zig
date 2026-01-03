// cmd/dipole/cli/attach_session.zig

const std = @import("std");
const attach_session_impl = @import("attach_session_impl");
const pane_runtime = @import("pane_runtime");

pub const PaneRole = pane_runtime.PaneRole;
pub const parsePaneRole = pane_runtime.parsePaneRole;
pub const FactCategory = attach_session_impl.FactCategory;
pub const SessionFact = attach_session_impl.SessionFact;

pub const SessionCommand = enum { interrupt, @"continue", detach };

pub fn shouldReadStdin(saw_any: bool, stdin_isatty: bool) bool {
    return stdin_isatty and !saw_any;
}

pub fn parseSessionCommand(token: []const u8) ?SessionCommand {
    if (std.mem.eql(u8, token, "interrupt")) return .interrupt;
    if (std.mem.eql(u8, token, "continue")) return .@"continue";
    if (std.mem.eql(u8, token, "detach")) return .detach;
    return null;
}

fn commandFor(token: SessionCommand) []const u8 {
    return switch (token) {
        .interrupt => "process interrupt\n",
        .@"continue" => "process continue\n",
        .detach => "detach\n",
    };
}

pub fn parseFactFlag(token: []const u8) ?FactCategory {
    if (std.mem.eql(u8, token, "--context")) return .context;
    if (std.mem.eql(u8, token, "--provenance")) return .provenance;
    return null;
}

pub fn parseAttachTokens(
    allocator: std.mem.Allocator,
    tokens: []const []const u8,
    commands: *std.ArrayList([]const u8),
    facts: *std.ArrayList(SessionFact),
) !bool {
    _ = allocator;
    var use_tmux = false;
    var i: usize = 0;
    while (i < tokens.len) {
        const token = tokens[i];
        if (std.mem.eql(u8, token, "--tmux")) {
            use_tmux = true;
            i += 1;
            continue;
        }
        if (parseFactFlag(token)) |fact_kind| {
            if (i + 1 >= tokens.len) return error.MissingSessionFactValue;
            const payload = tokens[i + 1];
            try facts.append(.{ .category = fact_kind, .payload = payload });
            i += 2;
            continue;
        }
        const cmd_token = parseSessionCommand(token) orelse {
            return error.InvalidSessionCommand;
        };
        try commands.append(commandFor(cmd_token));
        i += 1;
    }
    return use_tmux;
}

pub fn runAttach(
    allocator: std.mem.Allocator,
    pid: i32,
    args_iter: *std.process.ArgIterator,
    stdin: anytype,
) !void {
    var commands = std.ArrayList([]const u8).init(allocator);
    defer commands.deinit();
    var facts = std.ArrayList(SessionFact).init(allocator);
    defer facts.deinit();

    var tokens = std.ArrayList([]const u8).init(allocator);
    defer tokens.deinit();
    while (args_iter.next()) |token| {
        try tokens.append(token);
    }
    const use_tmux = try parseAttachTokens(allocator, tokens.items, &commands, &facts);

    const stdin_isatty = std.posix.isatty(std.posix.STDIN_FILENO);
    if (!use_tmux and commands.items.len == 0 and !stdin_isatty) {
        var line_buf: [256]u8 = undefined;
        while (true) {
            const line = (try stdin.readUntilDelimiterOrEof(&line_buf, '\n')) orelse break;
            if (line.len == 0) continue;
            const cmd_token = parseSessionCommand(line) orelse continue;
            try commands.append(commandFor(cmd_token));
        }
    }

    const interactive = shouldReadStdin(commands.items.len > 0, stdin_isatty);
    try attach_session_impl.runAttach(allocator, pid, commands.items, facts.items, use_tmux, interactive);
}

pub fn runAttachPane(
    cmd_fd: std.posix.fd_t,
    out_fd: std.posix.fd_t,
    source_id: u32,
    role: PaneRole,
) !void {
    try pane_runtime.runPane(
        std.heap.page_allocator,
        cmd_fd,
        out_fd,
        source_id,
        role,
        null,
    );
}

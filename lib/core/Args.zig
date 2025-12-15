const std = @import("std");

pub const RunParsed = struct {
    no_tmux: bool,
    exe: []const u8,
};

pub const ReplParsed = struct {
    no_tmux: bool,
    pid_str: []const u8,
};

pub fn shouldBootstrapTmux(no_tmux: bool) bool {
    return !no_tmux;
}

pub fn parseRun(next1: ?[]const u8, next2: ?[]const u8) !RunParsed {
    // next1 is first token after "run"
    // next2 is second token after "run" (only needed if next1 is flag)
    if (next1 == null) return error.InvalidArgs;

    var no_tmux = false;
    var exe: []const u8 = next1.?;

    if (std.mem.eql(u8, exe, "--no-tmux")) {
        no_tmux = true;
        if (next2 == null) return error.InvalidArgs;
        exe = next2.?;
    }

    return .{ .no_tmux = no_tmux, .exe = exe };
}

pub fn parseRepl(next1: ?[]const u8, next2: ?[]const u8) !ReplParsed {
    if (next1 == null) return error.InvalidArgs;

    var no_tmux = false;
    var pid_str: []const u8 = next1.?;

    if (std.mem.eql(u8, pid_str, "--no-tmux")) {
        no_tmux = true;
        if (next2 == null) return error.InvalidArgs;
        pid_str = next2.?;
    }

    return .{ .no_tmux = no_tmux, .pid_str = pid_str };
}

test "parseRun: no flag" {
    const p = try parseRun("app", null);
    try std.testing.expect(!p.no_tmux);
    try std.testing.expectEqualStrings("app", p.exe);
}

test "parseRun: --no-tmux" {
    const p = try parseRun("--no-tmux", "app");
    try std.testing.expect(p.no_tmux);
    try std.testing.expectEqualStrings("app", p.exe);
}

test "parseRun: missing exe after flag" {
    try std.testing.expectError(error.InvalidArgs, parseRun("--no-tmux", null));
}

test "parseRepl: no flag" {
    const p = try parseRepl("123", null);
    try std.testing.expect(!p.no_tmux);
    try std.testing.expectEqualStrings("123", p.pid_str);
}

test "parseRepl: --no-tmux" {
    const p = try parseRepl("--no-tmux", "123");
    try std.testing.expect(p.no_tmux);
    try std.testing.expectEqualStrings("123", p.pid_str);
}

test "parseRepl: missing pid after flag" {
    try std.testing.expectError(error.InvalidArgs, parseRepl("--no-tmux", null));
}

test "shouldBootstrapTmux" {
    try std.testing.expect(shouldBootstrapTmux(false));
    try std.testing.expect(!shouldBootstrapTmux(true));
}

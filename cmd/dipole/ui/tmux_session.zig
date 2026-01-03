//cmd/dipole/ui/tmux_session.zig

const std = @import("std");

pub const TmuxError = error{
    TmuxRequired,
    TmuxNewFailed,
    TmuxSplitFailed,
    TmuxAttachFailed,
};

pub fn runTmuxSession(
    allocator: std.mem.Allocator,
    session_name: []const u8,
    exe_path: []const u8,
    cmd_left_fd: std.posix.fd_t,
    cmd_right_fd: std.posix.fd_t,
    out_left_fd: std.posix.fd_t,
    out_right_fd: std.posix.fd_t,
    source_left_id: u32,
    source_right_id: u32,
    role_left: []const u8,
    role_right: []const u8,
) !void {
    var tmux_kill = std.process.Child.init(
        &.{ "tmux", "kill-session", "-t", session_name },
        allocator,
    );
    const kill_term = tmux_kill.spawnAndWait() catch return TmuxError.TmuxRequired;
    _ = kill_term;

    const cmd_left_str = try std.fmt.allocPrint(allocator, "{d}", .{cmd_left_fd});
    defer allocator.free(cmd_left_str);
    const cmd_right_str = try std.fmt.allocPrint(allocator, "{d}", .{cmd_right_fd});
    defer allocator.free(cmd_right_str);
    const out_left_str = try std.fmt.allocPrint(allocator, "{d}", .{out_left_fd});
    defer allocator.free(out_left_str);
    const out_right_str = try std.fmt.allocPrint(allocator, "{d}", .{out_right_fd});
    defer allocator.free(out_right_str);
    const source_left_str = try std.fmt.allocPrint(allocator, "{d}", .{source_left_id});
    defer allocator.free(source_left_str);
    const source_right_str = try std.fmt.allocPrint(allocator, "{d}", .{source_right_id});
    defer allocator.free(source_right_str);

    var tmux_new = std.process.Child.init(
        &.{
            "tmux",
            "new-session",
            "-d",
            "-s",
            session_name,
            exe_path,
            "attach-pane",
            "--cmd-fd",
            cmd_left_str,
            "--out-fd",
            out_left_str,
            "--source-id",
            source_left_str,
            "--pane-role",
            role_left,
        },
        allocator,
    );
    const new_term = tmux_new.spawnAndWait() catch return TmuxError.TmuxRequired;
    if (new_term != .Exited or new_term.Exited != 0) return TmuxError.TmuxNewFailed;

    var tmux_split = std.process.Child.init(
        &.{
            "tmux",
            "split-window",
            "-h",
            "-t",
            session_name,
            exe_path,
            "attach-pane",
            "--cmd-fd",
            cmd_right_str,
            "--out-fd",
            out_right_str,
            "--source-id",
            source_right_str,
            "--pane-role",
            role_right,
        },
        allocator,
    );
    const split_term = tmux_split.spawnAndWait() catch return TmuxError.TmuxRequired;
    if (split_term != .Exited or split_term.Exited != 0) return TmuxError.TmuxSplitFailed;

    if (cmd_left_fd >= 0) _ = std.posix.close(cmd_left_fd);
    if (cmd_right_fd >= 0) _ = std.posix.close(cmd_right_fd);

    var tmux_attach = std.process.Child.init(
        &.{ "tmux", "attach-session", "-t", session_name },
        allocator,
    );
    const attach_term = tmux_attach.spawnAndWait() catch return TmuxError.TmuxRequired;
    if (attach_term != .Exited or attach_term.Exited != 0) return TmuxError.TmuxAttachFailed;
}

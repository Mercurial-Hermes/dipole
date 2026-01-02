const std = @import("std");
const controller = @import("controller");
const debug_session = @import("debug_session");
const lldb_launcher = @import("lldb_launcher");
const pty_raw_driver = @import("pty_raw_driver");
const request_envelope = @import("request_envelope");
const fd_utils = @import("fd_utils");
const pane_runtime = @import("pane_runtime");
const tmux_session = @import("tmux_session");

const Session = struct {
    launcher: lldb_launcher.LLDBLauncher,
    driver_impl: pty_raw_driver.PtyRawDriver,
    debug_session: *debug_session.DebugSession,
};

const default_source_id: u32 = 1;
const synthetic_source_id: u32 = 2;

const ControllerThreadArgs = struct {
    ctl: *controller.Controller,
    cmd_read_fd: std.posix.fd_t,
    out_write_fds: []std.posix.fd_t,
    pty_poll_fd: std.posix.fd_t,
};

fn controllerThreadMain(args: ControllerThreadArgs) void {
    _ = args.ctl.runBroker(
        args.cmd_read_fd,
        args.out_write_fds,
        args.pty_poll_fd,
    ) catch {};
}

fn drainOutput(out_fd: std.posix.fd_t, sink: std.fs.File) !void {
    var buf: [1024]u8 = undefined;
    const stdout = std.io.getStdOut().writer();
    const sink_writer = sink.writer();
    while (true) {
        const n = std.posix.read(out_fd, &buf) catch |err| switch (err) {
            error.WouldBlock => 0,
            else => return err,
        };
        if (n == 0) break;
        try stdout.writeAll(buf[0..n]);
        try sink_writer.writeAll(buf[0..n]);
    }
}

fn sendCommands(cmd_fd: std.posix.fd_t, commands: []const []const u8) !void {
    for (commands) |cmd| {
        try request_envelope.writeEnvelope(cmd_fd, default_source_id, cmd);
    }
}

fn runDirectSession(
    session: *Session,
    commands: []const []const u8,
    interactive: bool,
) !void {
    var cmd_fds = try fd_utils.createPipe();
    defer fd_utils.closeFd(&cmd_fds[1]);
    var out_fds = try fd_utils.createPipe();
    defer fd_utils.closeFd(&out_fds[0]);
    try fd_utils.setNonblocking(out_fds[1], true);

    var sink_file = try std.fs.createFileAbsolute("/tmp/dipole-lldb-sink.log", .{});
    defer sink_file.close();

    var ctl = controller.Controller.init(
        session.driver_impl.allocator,
        session.debug_session,
        session.driver_impl.asDriver(),
    );
    var out_write_fds = [_]std.posix.fd_t{out_fds[1]};
    const thread = try std.Thread.spawn(.{}, controllerThreadMain, .{ControllerThreadArgs{
        .ctl = &ctl,
        .cmd_read_fd = cmd_fds[0],
        .out_write_fds = out_write_fds[0..],
        .pty_poll_fd = session.driver_impl.master_fd,
    }});

    // Control-plane validation: a second source_id sharing the same Controller.
    try request_envelope.writeEnvelope(cmd_fds[1], synthetic_source_id, "help\n");

    if (commands.len > 0) {
        try sendCommands(cmd_fds[1], commands);
        fd_utils.closeFd(&cmd_fds[1]);
        try drainOutput(out_fds[0], sink_file);
        thread.join();
        return;
    }

    if (interactive) {
        try pane_runtime.runPane(cmd_fds[1], out_fds[0], default_source_id, .repl, sink_file);
        thread.join();
        return;
    }

    fd_utils.closeFd(&cmd_fds[1]);
    try drainOutput(out_fds[0], sink_file);
    thread.join();
}

fn runTmuxSession(
    session: *Session,
    allocator: std.mem.Allocator,
    pid: i32,
    commands: []const []const u8,
) !void {
    var cmd_fds = try fd_utils.createPipe();
    defer fd_utils.closeFd(&cmd_fds[1]);
    var out_left = try fd_utils.createPipe();
    defer fd_utils.closeFd(&out_left[0]);
    var out_right = try fd_utils.createPipe();
    defer fd_utils.closeFd(&out_right[0]);

    try fd_utils.setNonblocking(out_left[1], true);
    try fd_utils.setNonblocking(out_right[1], true);

    try fd_utils.setCloexec(cmd_fds[0], true);
    try fd_utils.setCloexec(out_left[1], true);
    try fd_utils.setCloexec(out_right[1], true);
    try fd_utils.setCloexec(cmd_fds[1], false);
    try fd_utils.setCloexec(out_left[0], false);
    try fd_utils.setCloexec(out_right[0], false);

    var ctl = controller.Controller.init(
        session.driver_impl.allocator,
        session.debug_session,
        session.driver_impl.asDriver(),
    );
    var out_write_fds = [_]std.posix.fd_t{ out_left[1], out_right[1] };
    const thread = try std.Thread.spawn(.{}, controllerThreadMain, .{ControllerThreadArgs{
        .ctl = &ctl,
        .cmd_read_fd = cmd_fds[0],
        .out_write_fds = out_write_fds[0..],
        .pty_poll_fd = session.driver_impl.master_fd,
    }});

    // Control-plane validation: a second source_id sharing the same Controller.
    try request_envelope.writeEnvelope(cmd_fds[1], synthetic_source_id, "help\n");
    try sendCommands(cmd_fds[1], commands);

    const exe_path = try std.fs.selfExePathAlloc(allocator);
    defer allocator.free(exe_path);
    const session_name = try std.fmt.allocPrint(allocator, "dipole-{d}", .{pid});
    defer allocator.free(session_name);

    try tmux_session.runTmuxSession(
        allocator,
        session_name,
        exe_path,
        cmd_fds[1],
        out_left[0],
        out_right[0],
        default_source_id,
        synthetic_source_id,
        "repl",
        "output",
    );

    fd_utils.closeFd(&cmd_fds[1]);
    thread.join();
}

pub fn runAttach(
    allocator: std.mem.Allocator,
    pid: i32,
    commands: []const []const u8,
    use_tmux: bool,
    interactive: bool,
) !void {
    const launcher = try lldb_launcher.LLDBLauncher.attach(pid);
    var dbg_session = debug_session.DebugSession.init(allocator);
    defer dbg_session.deinit();
    var session = Session{
        .launcher = launcher,
        .driver_impl = pty_raw_driver.PtyRawDriver.init(allocator, launcher.master_fd),
        .debug_session = &dbg_session,
    };
    defer {
        _ = session.launcher.shutdown() catch {};
        session.driver_impl.master_fd = -1;
        session.driver_impl.deinit();
    }

    if (use_tmux) {
        return runTmuxSession(&session, allocator, pid, commands);
    }

    try runDirectSession(&session, commands, interactive);
}

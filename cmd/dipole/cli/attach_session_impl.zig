// cmd/dipole/cli/attach_session_impl.zig

const std = @import("std");
const controller = @import("controller");
const debug_session = @import("debug_session");
const lldb_launcher = @import("lldb_launcher");
const pty_raw_driver = @import("pty_raw_driver");
const request_envelope = @import("request_envelope");
const fd_utils = @import("fd_utils");
const pane_runtime = @import("pane_runtime");
const tmux_session = @import("tmux_session");
const projection = @import("projection");

const Session = struct {
    launcher: lldb_launcher.LLDBLauncher,
    driver_impl: pty_raw_driver.PtyRawDriver,
    debug_session: *debug_session.DebugSession,
};

const default_source_id: u32 = 1;
const synthetic_source_id: u32 = 2;

fn drainLogOnce(out_fd: std.posix.fd_t, sink: std.fs.File) !void {
    var buf: [1024]u8 = undefined;
    const sink_writer = sink.writer();
    while (true) {
        const n = std.posix.read(out_fd, &buf) catch |err| switch (err) {
            error.WouldBlock => 0,
            else => return err,
        };
        if (n == 0) return;
        try sink_writer.writeAll(buf[0..n]);
    }
}

fn sendCommands(cmd_fd: std.posix.fd_t, commands: []const []const u8) !void {
    for (commands) |cmd| {
        try request_envelope.writeEnvelope(cmd_fd, default_source_id, cmd);
    }
}

fn writeProjectionOutput(out_fd: std.posix.fd_t, bytes: []const u8) void {
    if (out_fd < 0) return;
    _ = std.posix.write(out_fd, bytes) catch {};
}

fn runProjectionLoop(
    ctl: *controller.Controller,
    cmd_read_fd: std.posix.fd_t,
    out_write_fds: []std.posix.fd_t,
    pty_poll_fd: std.posix.fd_t,
    log_read_fd: std.posix.fd_t,
    log_sink: std.fs.File,
    proj_write_fd: std.posix.fd_t,
) !void {
    var last_snapshot_event_id: ?u64 = null;
    var empty_emitted = false;

    while (true) {
        const cmd_closed = try ctl.drainOnce(cmd_read_fd, out_write_fds, pty_poll_fd);
        try drainLogOnce(log_read_fd, log_sink);

        const view = projection.latestRegisterSnapshot(ctl.session.eventsView());
        switch (view.status) {
            .empty => {
                if (!empty_emitted and proj_write_fd >= 0) {
                    writeProjectionOutput(proj_write_fd, "[no registers]\n");
                    empty_emitted = true;
                }
            },
            .present => {
                if (view.snapshot_event_id != null and view.snapshot_event_id.? != last_snapshot_event_id) {
                    writeProjectionOutput(proj_write_fd, view.payload_bytes);
                    last_snapshot_event_id = view.snapshot_event_id;
                }
            },
        }

        if (cmd_closed) break;
        std.time.sleep(5 * std.time.ns_per_ms);
    }
}

fn runDirectSession(
    session: *Session,
    commands: []const []const u8,
    interactive: bool,
) !void {
    var cmd_fds = try fd_utils.createPipe();
    defer fd_utils.closeFd(&cmd_fds[0]);
    var out_fds = try fd_utils.createPipe();
    defer fd_utils.closeFd(&out_fds[0]);
    defer fd_utils.closeFd(&out_fds[1]);
    try fd_utils.setNonblocking(out_fds[1], true);
    try fd_utils.setNonblocking(out_fds[0], true);

    var sink_file = try std.fs.createFileAbsolute("/tmp/dipole-lldb-sink.log", .{});
    defer sink_file.close();

    var ctl = controller.Controller.init(
        session.driver_impl.allocator,
        session.debug_session,
        session.driver_impl.asDriver(),
    );
    var out_write_fds = [_]std.posix.fd_t{out_fds[1]};

    if (commands.len > 0) {
        for (commands) |cmd| {
            try request_envelope.writeEnvelope(cmd_fds[1], default_source_id, cmd);
        }
        fd_utils.closeFd(&cmd_fds[1]);
        try runProjectionLoop(
            &ctl,
            cmd_fds[0],
            out_write_fds[0..],
            session.driver_impl.master_fd,
            out_fds[0],
            sink_file,
            -1,
        );
        return;
    }

    if (interactive) {
        const repl_thread = try std.Thread.spawn(.{}, pane_runtime.runPane, .{
            session.driver_impl.allocator,
            cmd_fds[1],
            -1,
            default_source_id,
            .repl,
            null,
        });
        try runProjectionLoop(
            &ctl,
            cmd_fds[0],
            out_write_fds[0..],
            session.driver_impl.master_fd,
            out_fds[0],
            sink_file,
            -1,
        );
        repl_thread.join();
        return;
    }

    fd_utils.closeFd(&cmd_fds[1]);
    try runProjectionLoop(
        &ctl,
        cmd_fds[0],
        out_write_fds[0..],
        session.driver_impl.master_fd,
        out_fds[0],
        sink_file,
        -1,
    );
}

fn runTmuxSession(
    session: *Session,
    allocator: std.mem.Allocator,
    pid: i32,
    commands: []const []const u8,
) !void {
    var cmd_fds = try fd_utils.createPipe();
    defer fd_utils.closeFd(&cmd_fds[0]);
    var out_fds = try fd_utils.createPipe();
    defer fd_utils.closeFd(&out_fds[0]);
    defer fd_utils.closeFd(&out_fds[1]);
    var proj_fds = try fd_utils.createPipe();
    defer fd_utils.closeFd(&proj_fds[0]);
    defer fd_utils.closeFd(&proj_fds[1]);

    try fd_utils.setNonblocking(out_fds[1], true);
    try fd_utils.setNonblocking(out_fds[0], true);
    try fd_utils.setNonblocking(proj_fds[1], true);

    try fd_utils.setCloexec(cmd_fds[0], true);
    try fd_utils.setCloexec(out_fds[1], true);
    try fd_utils.setCloexec(out_fds[0], false);
    try fd_utils.setCloexec(proj_fds[1], true);
    try fd_utils.setCloexec(proj_fds[0], false);
    try fd_utils.setCloexec(cmd_fds[1], false);

    var ctl = controller.Controller.init(
        session.driver_impl.allocator,
        session.debug_session,
        session.driver_impl.asDriver(),
    );
    var out_write_fds = [_]std.posix.fd_t{out_fds[1]};

    try sendCommands(cmd_fds[1], commands);

    var sink_file = try std.fs.createFileAbsolute("/tmp/dipole-lldb-sink.log", .{});
    defer sink_file.close();

    const exe_path = try std.fs.selfExePathAlloc(allocator);
    defer allocator.free(exe_path);
    const session_name = try std.fmt.allocPrint(allocator, "dipole-{d}", .{pid});
    defer allocator.free(session_name);

    const tmux_thread = try std.Thread.spawn(.{}, tmux_session.runTmuxSession, .{
        allocator,
        session_name,
        exe_path,
        cmd_fds[1],
        -1,
        -1,
        proj_fds[0],
        default_source_id,
        synthetic_source_id,
        "repl",
        "output",
    });

    try runProjectionLoop(
        &ctl,
        cmd_fds[0],
        out_write_fds[0..],
        session.driver_impl.master_fd,
        out_fds[0],
        sink_file,
        proj_fds[1],
    );

    tmux_thread.join();
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

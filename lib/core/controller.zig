/// Controller.zig
///
/// See docs/architecture/dipole-minimal-type-graph.md
/// See docs/architecture/dipole-module-boundary.md
/// See docs/architecture/execution-source.md
/// See docs/architecture/interaction-flow.md
///
/// A Controller brokers the interaction with the debugger
/// It talks to the driver and admits observations as Events
/// It enforces order and sequence of events
///
const std = @import("std");
const EventMod = @import("event");
const DebugSessionMod = @import("debug_session.zig");
const DriverMod = @import("driver");
const request_envelope = @import("request_envelope");
pub const Event = EventMod.Event;
pub const Category = EventMod.Category;
pub const SnapshotKind = EventMod.SnapshotKind;
pub const DebugSession = DebugSessionMod.DebugSession;
pub const Driver = DriverMod.Driver;
pub const DriverObservation = DriverMod.DriverObservation;
const posix = std.posix;

pub const Controller = struct {
    /// Reserved for future event payload allocation / async ingestion
    allocator: std.mem.Allocator,
    session: *DebugSession,
    driver: Driver,

    pub fn init(
        allocator: std.mem.Allocator,
        session: *DebugSession,
        driver: Driver,
    ) Controller {
        return .{
            .allocator = allocator,
            .session = session,
            .driver = driver,
        };
    }

    pub fn issueRawCommand(self: *Controller, line: []const u8) !void {
        const payload = try self.allocator.dupe(u8, line);
        try self.session.appendWithPayload(.command, payload);
        try self.driver.send(self.driver.ctx, line);

        while (self.driver.poll(self.driver.ctx)) |obs| {
            // Transport-level observation → coarse, non-semantic category
            switch (obs) {
                .tx => |bytes| {
                    defer self.allocator.free(bytes);
                },
                .rx => |bytes| {
                    defer self.allocator.free(bytes);
                    const rx_payload = try self.allocator.dupe(u8, bytes);
                    try self.session.appendWithPayload(.backend, rx_payload);
                },
                .prompt => {
                    try self.session.append(.backend);
                },
            }
        }
    }

    fn isExecCommand(payload: []const u8) bool {
        return std.mem.eql(u8, payload, "thread step-in\n") or
            std.mem.eql(u8, payload, "thread step-over\n") or
            std.mem.eql(u8, payload, "process continue\n");
    }

    fn ingestDriverCapture(self: *Controller, out_write_fds: []posix.fd_t, capture: *std.ArrayList(u8)) !void {
        while (self.driver.poll(self.driver.ctx)) |obs| {
            switch (obs) {
                .tx => |bytes| {
                    defer self.allocator.free(bytes);
                },
                .rx => |bytes| {
                    defer self.allocator.free(bytes);
                    writeToFds(out_write_fds, bytes);
                    const payload = try self.allocator.dupe(u8, bytes);
                    try self.session.appendWithPayload(.backend, payload);
                    try capture.appendSlice(bytes);
                },
                .prompt => {
                    try self.session.append(.backend);
                },
            }
        }
    }

    fn emitRegisterSnapshot(self: *Controller, source_id: u32, out_write_fds: []posix.fd_t) !void {
        try self.ingestDriver(out_write_fds);
        const cmd = "register read\n";
        try self.driver.send(self.driver.ctx, cmd);
        const cmd_payload = try self.allocator.dupe(u8, cmd);
        try self.session.appendWithPayload(.command, cmd_payload);

        var capture = std.ArrayList(u8).init(self.allocator);
        defer capture.deinit();
        try self.ingestDriverCapture(out_write_fds, &capture);

        // captured_at_event_seq anchors the snapshot to the last event
        // admitted prior to snapshot admission. It must never refer
        // to the snapshot event itself.
        const captured_at_event_seq = self.session.nextEventSeq() - 1;
        try self.session.appendSnapshot(.registers, source_id, captured_at_event_seq, capture.items);
    }

    /// Broker loop: single ingress for command and observation.
    /// Reads from command pipe, polls Driver, writes raw output to pipe(s).
    pub fn runBroker(
        self: *Controller,
        cmd_read_fd: posix.fd_t,
        out_write_fds: []posix.fd_t,
        pty_poll_fd: posix.fd_t,
    ) !void {
        var fds = [_]posix.pollfd{
            .{ .fd = cmd_read_fd, .events = posix.POLL.IN, .revents = 0 },
            .{ .fd = pty_poll_fd, .events = posix.POLL.IN, .revents = 0 },
        };

        var cmd_closed = false;

        while (true) {
            fds[0].revents = 0;
            fds[1].revents = 0;

            _ = try posix.poll(&fds, -1);

            if (fds[0].revents & posix.POLL.IN != 0) {
                const env = request_envelope.readEnvelope(self.allocator, cmd_read_fd) catch |err| switch (err) {
                    error.EndOfStream => null,
                    else => return err,
                };
                if (env) |e| {
                    const exec_cmd = isExecCommand(e.payload);
                    errdefer self.allocator.free(e.payload);
                    try self.driver.send(self.driver.ctx, e.payload);
                    try self.session.appendWithPayload(.command, e.payload);
                    if (exec_cmd) {
                        try self.emitRegisterSnapshot(e.source_id, out_write_fds);
                    }
                } else {
                    cmd_closed = true;
                }
            }

            if (fds[1].revents & posix.POLL.IN != 0) {
                try self.ingestDriver(out_write_fds);
            }

            if (cmd_closed) {
                try self.ingestDriver(out_write_fds);
                closeFd(cmd_read_fd);
                closeFds(out_write_fds);
                return;
            }
        }
    }

    pub fn drainOnce(
        self: *Controller,
        cmd_read_fd: posix.fd_t,
        out_write_fds: []posix.fd_t,
        pty_poll_fd: posix.fd_t,
    ) !bool {
        var fds = [_]posix.pollfd{
            .{ .fd = cmd_read_fd, .events = posix.POLL.IN, .revents = 0 },
            .{ .fd = pty_poll_fd, .events = posix.POLL.IN, .revents = 0 },
        };

        while (true) {
            fds[0].revents = 0;
            fds[1].revents = 0;
            const ready = try posix.poll(&fds, 0);
            if (ready == 0) return false;

            if (fds[0].revents & posix.POLL.IN != 0) {
                const env = request_envelope.readEnvelope(self.allocator, cmd_read_fd) catch |err| switch (err) {
                    error.EndOfStream => null,
                    else => return err,
                };
                if (env) |e| {
                    const exec_cmd = isExecCommand(e.payload);
                    errdefer self.allocator.free(e.payload);
                    try self.driver.send(self.driver.ctx, e.payload);
                    try self.session.appendWithPayload(.command, e.payload);
                    if (exec_cmd) {
                        try self.emitRegisterSnapshot(e.source_id, out_write_fds);
                    }
                } else {
                    return true;
                }
            }

            if (fds[1].revents & posix.POLL.IN != 0) {
                try self.ingestDriver(out_write_fds);
            }
        }
    }

    fn ingestDriver(self: *Controller, out_write_fds: []posix.fd_t) !void {
        while (self.driver.poll(self.driver.ctx)) |obs| {
            switch (obs) {
                .tx => |bytes| {
                    defer self.allocator.free(bytes);
                },
                .rx => |bytes| {
                    defer self.allocator.free(bytes);
                    writeToFds(out_write_fds, bytes);
                    const payload = try self.allocator.dupe(u8, bytes);
                    try self.session.appendWithPayload(.backend, payload);
                },
                .prompt => {
                    try self.session.append(.backend);
                },
            }
        }
    }
};

fn writeToFds(fds: []posix.fd_t, buf: []const u8) void {
    for (fds) |*fd| {
        if (fd.* < 0) continue;
        _ = posix.write(fd.*, buf) catch |err| {
            switch (err) {
                error.WouldBlock,
                error.BrokenPipe,
                error.NotOpenForWriting,
                error.InputOutput,
                => {
                    fd.* = -1;
                    return;
                },
                else => {
                    fd.* = -1;
                    return;
                },
            }
        };
    }
}

fn closeFd(fd: posix.fd_t) void {
    if (fd >= 0) {
        _ = posix.close(fd);
    }
}

fn closeFds(fds: []posix.fd_t) void {
    for (fds) |*fd| {
        if (fd.* >= 0) {
            _ = posix.close(fd.*);
            fd.* = -1;
        }
    }
}

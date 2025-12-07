const std = @import("std");

pub const Driver = struct {
    allocator: std.mem.Allocator,
    child: std.process.Child,
    stdin: std.io.AnyWriter,
    stdout: std.io.AnyReader,
    stderr: std.io.AnyReader,
    stdout_fd: std.posix.fd_t,
    stderr_fd: std.posix.fd_t,

    pub fn init(allocator: std.mem.Allocator) !Driver {
        // 1. create child
        // Interactive mode (no --batch) so commands execute immediately; --source /dev/null prevents loading user scripts.
        var child = std.process.Child.init(&[_][]const u8{ "lldb", "--no-lldbinit", "--source", "/dev/null" }, allocator);
        // 2. set .stdin/.stdout/.stderr to .Pipe
        child.stdin_behavior = .Pipe;
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Pipe;
        // 3. spawn it
        try child.spawn();
        // 4. extract pipe handles
        const stdin_writer = child.stdin.?.writer();
        const stdout_file = child.stdout orelse return error.NoStdoutPipe;
        const stderr_file = child.stderr orelse return error.NoStderrPipe;
        const stdout_reader = stdout_file.reader();
        const stderr_reader = stderr_file.reader();
        // 5. return LLDBDriver instance
        var driver = Driver{
            .allocator = allocator,
            .child = child,
            .stdin = stdin_writer.any(), // convert to AnyWriter
            .stdout = stdout_reader.any(), // convert to AnyReader
            .stderr = stderr_reader.any(),
            .stdout_fd = stdout_file.handle,
            .stderr_fd = stderr_file.handle,
        };

        _ = try driver.readUntilPrompt(allocator); // Now LLDB is synced

        return driver;
    }

    pub fn deinit(self: *Driver) void {
        // Best effort wait — LLDB normally exits cleanly.
        _ = self.child.wait() catch {};
    }

    pub fn writeCommand(self: *Driver, cmd: []const u8) !void {
        std.debug.print("[lldb] >> {s}\n", .{cmd});
        try self.stdin.writeAll(cmd);
        try self.stdin.writeAll("\n");
    }

    pub fn attachPid(self: *Driver, pid: i32) !void {
        var buf: [32]u8 = undefined;
        const cmd = try std.fmt.bufPrint(&buf, "attach --pid {d}", .{pid});

        try self.writeCommand(cmd);
        const output = try self.readUntilPrompt(self.allocator);

        if (std.mem.containsAtLeast(u8, output, 1, "error:")) {
            return error.LLDBAttachFailed;
        }
    }

    pub fn stepInstruction(self: *Driver) !void {
        try self.writeCommand("stepi");
        _ = try self.readUntilPrompt(self.allocator);
    }

    pub fn readUntilPrompt(self: *Driver, allocator: std.mem.Allocator) ![]u8 {
        var buffer = std.ArrayList(u8).init(allocator);

        const start_time = std.time.nanoTimestamp();
        var last_progress = start_time;

        while (true) {
            const now = std.time.nanoTimestamp();
            // overall timeout: 3s — attach/read can pause the target
            if (now - start_time > 3_000_000_000) {
                std.debug.print("[lldb] !! timeout waiting for output (buffer so far {d} bytes)\n", .{buffer.items.len});
                break;
            }

            var fds = [_]std.posix.pollfd{
                .{ .fd = self.stdout_fd, .events = std.posix.POLL.IN, .revents = 0 },
                .{ .fd = self.stderr_fd, .events = std.posix.POLL.IN, .revents = 0 },
            };
            // wait up to 5ms for readability
            _ = std.posix.poll(&fds, 5) catch {};

            var made_progress = false;

            if (fds[0].revents & std.posix.POLL.IN != 0) {
                var temp: [512]u8 = undefined;
                const n = self.stdout.read(&temp) catch |err| {
                    if (err == error.WouldBlock) {
                        // nothing ready yet; back off briefly
                        std.time.sleep(1_000_000); // 1ms
                        continue;
                    }
                    if (err == error.NotOpenForReading) break;
                    return err;
                };

                if (n > 0) {
                    try buffer.appendSlice(temp[0..n]);
                    made_progress = true;
                }
            }

            if (fds[1].revents & std.posix.POLL.IN != 0) {
                var temp_err: [512]u8 = undefined;
                const nerr = self.stderr.read(&temp_err) catch |err| {
                    if (err == error.WouldBlock) {
                        std.time.sleep(1_000_000);
                        continue;
                    }
                    if (err == error.NotOpenForReading) break;
                    return err;
                };
                if (nerr > 0) {
                    try buffer.appendSlice(temp_err[0..nerr]);
                    made_progress = true;
                }
            }

            if (made_progress) {
                last_progress = now;
            } else {
                // if no output for 1s, assume LLDB is idle for this command
                if (now - last_progress > 1_000_000_000) {
                    std.debug.print("[lldb] !! idle timeout (buffer {d} bytes)\n", .{buffer.items.len});
                    break;
                }
            }

            // break if LLDB *does* print a prompt, but not required
            if (std.mem.indexOf(u8, buffer.items, "(lldb)") != null) {
                break;
            }
        }

        const out = try buffer.toOwnedSlice();
        if (out.len > 0) {
            std.debug.print("[lldb] << {s}\n", .{out});
        }
        return out;
    }

    pub fn readPc(self: *Driver) !usize {
        try self.writeCommand("register read pc");
        const output = try self.readUntilPrompt(self.allocator);

        return try parsePc(output);
    }

    pub fn parsePc(output: []const u8) !usize {
        const needle = "pc = 0x";
        const start = std.mem.indexOf(u8, output, needle) orelse
            return error.PcNotFound;

        const hex_start = start + needle.len;

        // read until non-hex
        var i: usize = hex_start;
        while (i < output.len) : (i += 1) {
            const c = output[i];
            if (!(std.ascii.isHex(c))) break;
        }

        const hex_slice = output[hex_start..i];
        return std.fmt.parseInt(usize, hex_slice, 16);
    }

    pub fn detach(self: *Driver) !void {
        try self.writeCommand("detach");
        _ = try self.readUntilPrompt(self.allocator);
    }

    pub fn quit(self: *Driver) !void {
        try self.writeCommand("quit");
        // LLDB usually prints stuff, but we don't need to read it
    }
};

test "Driver compiles" {
    _ = Driver;
}

test "writeCommand writes command + newline" {
    var buf: [64]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);

    var fake_driver = Driver{
        .allocator = std.testing.allocator,
        .child = undefined, // unused
        .stdin = fbs.writer().any(),
        .stdout = undefined, // unused
    };

    try fake_driver.writeCommand("register read pc");

    const written = fbs.getWritten();
    try std.testing.expectEqualStrings("register read pc\n", written);
}

test "parsePc parses hex pc" {
    const sample =
        \\some output
        \\pc = 0x100003f80
        \\(lldb)
    ;
    const result = try Driver.parsePc(sample);
    try std.testing.expect(result == 0x100003f80);
}

test "parsePc fails gracefully if no pc line" {
    const sample = "no registers here";
    try std.testing.expectError(error.PcNotFound, Driver.parsePc(sample));
}

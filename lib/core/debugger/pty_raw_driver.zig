/// PtyRawDriver
///
/// See docs/architecture/execution-source.md
/// See docs/architecture/interaction-flow.md
/// See docs/architecture/dipole-module-boundary.md
///
/// Transport-backed implementation of the `Driver` boundary.
///
/// This type observes a non-blocking file descriptor and emits
/// raw transport observations exactly as they are read.
///
/// It must not:
///   - parse output
///   - detect prompts
///   - buffer across polls
///   - aggregate fragments
///   - infer execution state
///
/// Any such logic belongs *above* the Driver boundary.
///
/// This driver exists to introduce real transport noise (TS1-004)
/// without violating ingress invariants.
const std = @import("std");
const driver = @import("driver");

pub const PtyRawDriver = struct {
    allocator: std.mem.Allocator,
    master_fd: std.posix.fd_t,
    /// Temporary read buffer reused across polls.
    /// Contents are copied into owned slices before emission.
    read_buf: [1024]u8,

    pub fn init(
        allocator: std.mem.Allocator,
        master_fd: std.posix.fd_t,
    ) PtyRawDriver {
        return .{
            .allocator = allocator,
            .master_fd = master_fd,
            .read_buf = undefined,
        };
    }

    pub fn deinit(self: *PtyRawDriver) void {
        if (self.master_fd >= 0) {
            _ = std.posix.close(self.master_fd);
            self.master_fd = -1;
        }
    }

    /// Driver.send implementation
    pub fn send(ctx: *anyopaque, line: []const u8) anyerror!void {
        const self: *PtyRawDriver = @ptrCast(@alignCast(ctx));

        var total_written: usize = 0;
        while (total_written < line.len) {
            const n = try std.posix.write(
                self.master_fd,
                line[total_written..],
            );
            if (n == 0) return error.WriteFailed;
            total_written += n;
        }
    }

    /// Driver.poll implementation
    pub fn poll(ctx: *anyopaque) ?driver.DriverObservation {
        const self: *PtyRawDriver = @ptrCast(@alignCast(ctx));

        // Any transport error is treated as absence of observation.
        // Failure semantics are handled above the Driver boundary.
        const n = std.posix.read(self.master_fd, &self.read_buf) catch |err| switch (err) {
            error.WouldBlock => return null,
            else => return null, // transport failure → silent for now
        };

        if (n == 0) {
            // EOF — backend closed
            return null;
        }

        // Copy out exactly what we observed
        const slice = self.allocator.alloc(u8, n) catch return null;
        @memcpy(slice, self.read_buf[0..n]);

        return .{ .rx = slice };
    }

    /// Produce a Driver boundary object
    pub fn asDriver(self: *PtyRawDriver) driver.Driver {
        return driver.Driver{
            .ctx = self,
            .send = send,
            .poll = poll,
        };
    }
};

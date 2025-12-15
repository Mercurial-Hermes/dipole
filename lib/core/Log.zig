const std = @import("std");
const c = @cImport({
    @cInclude("time.h");
});

pub const Logger = struct {
    file: ?std.fs.File = null,

    fn makeTimestamp(buf: []u8) []const u8 {
        var now: c.time_t = @intCast(std.time.timestamp());

        var tm: c.struct_tm = undefined;

        // Convert UTC → local timezone (Brisbane)
        // Brisbane is system local timezone if macOS is set correctly.
        _ = c.localtime_r(&now, &tm);

        // Format: YYYY-MM-DD HH:MM:SS
        const fmt = "%Y-%m-%d %H:%M:%S";

        const written = c.strftime(buf.ptr, buf.len, fmt, &tm);
        if (written == 0) return "0000-00-00 00:00:00";

        return buf[0..written];
    }

    pub fn init() Logger {
        // Try opening the log file in write_only mode (must already exist)
        var file = std.fs.openFileAbsolute(
            "/tmp/dipole.log",
            .{ .mode = .write_only },
        ) catch null;

        // If it didn't exist, create it
        if (file == null) {
            file = std.fs.createFileAbsolute("/tmp/dipole.log", .{}) catch null;
        }

        return Logger{ .file = file };
    }

    pub fn deinit(self: *Logger) void {
        if (self.file) |f| f.close();
        self.file = null;
    }

    pub fn log(self: *Logger, comptime fmt: []const u8, args: anytype) void {
        if (self.file) |f| {
            var ts_buf: [32]u8 = undefined;
            const ts = makeTimestamp(&ts_buf);

            // Example: "2025-01-11 09:25:33 LLDBDriver: spawning..."
            f.writer().print("{s} " ++ fmt ++ "\n", .{ts} ++ args) catch {};
        }
    }
};

var GLOBAL: Logger = undefined;
var INITIALIZED: bool = false;

pub fn get() *Logger {
    if (!INITIALIZED) {
        GLOBAL = Logger.init();
        INITIALIZED = true;
    }
    return &GLOBAL;
}

pub fn log(comptime fmt: []const u8, args: anytype) void {
    get().log(fmt, args);
}

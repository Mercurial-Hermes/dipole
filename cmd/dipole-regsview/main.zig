const std = @import("std");
const RegsViewer = @import("regsview").RegsViewer;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var it = try std.process.argsWithAllocator(alloc);
    defer it.deinit();

    _ = it.next(); // argv0

    var path_opt: ?[]const u8 = null;

    while (it.next()) |arg| {
        if (std.mem.eql(u8, arg, "--path")) {
            path_opt = it.next() orelse return error.MissingPath;
        } else if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            try std.io.getStdOut().writer().writeAll(
                "dipole-regsview [--path <file>]\n",
            );
            return;
        }
    }

    const path = path_opt orelse std.posix.getenv("DIPOLE_REG_PATH") orelse return error.MissingPath;
    try RegsViewer.run(path);
}

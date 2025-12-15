const std = @import("std");
const Ansi = @import("ansi");
const Panes = @import("panes");
const Term = @import("term");

pub const RegsViewer = struct {
    /// Write one frame of output:
    /// - Clear screen
    /// - Print file contents or placeholder
    pub fn renderOnce(
        alloc: std.mem.Allocator,
        writer: anytype,
        dir: std.fs.Dir,
        filename: []const u8,
        width: usize,
        height: usize,
    ) !void {
        // Clear screen + move cursor home
        try writer.writeAll("\x1b[2J\x1b[H");

        const TOP_MARGIN: usize = 3;

        // Clear screen + move cursor home
        try writer.writeAll("\x1b[2J\x1b[H");

        // Move cursor down without emitting newlines (avoids scroll)
        try writer.print("\x1b[{d};{d}H", .{ TOP_MARGIN + 1, 1 });

        // Use remaining height for the box
        const box_h = if (height > TOP_MARGIN) height - TOP_MARGIN else 1;

        // Read regs text (or placeholder)
        var text: []u8 = undefined;

        const file = dir.openFile(filename, .{}) catch {
            text = try alloc.dupe(u8, "(waiting for registers...)\n");
            defer alloc.free(text);

            const boxed = try Panes.boxSingle(alloc, "Registers", text, width, box_h);
            defer alloc.free(boxed);

            try writer.writeAll(boxed);
            return;
        };
        defer file.close();

        text = try file.readToEndAlloc(alloc, 1 << 20); // 1MB cap is plenty
        defer alloc.free(text);

        // OPTIONAL: if your snapshot includes ANSI, strip it here (match your panes behavior)
        // text = try Panes.stripAnsiOwned(alloc, text); ...

        const boxed = try Panes.boxSingle(alloc, "Registers", text, width, box_h);
        defer alloc.free(boxed);

        try writer.writeAll(boxed);
    }

    /// Run in a loop printing file contents every 200ms
    pub fn run(path: []const u8) !void {
        const alloc = std.heap.page_allocator;
        const full = std.fs.path.resolve(alloc, &[_][]const u8{path}) catch path;
        defer if (full.ptr != path.ptr) alloc.free(full);

        // Split into directory + filename
        const slash = std.mem.lastIndexOfScalar(u8, full, '/') orelse return error.InvalidPath;

        const dir_path = full[0..slash];
        const filename = full[slash + 1 ..];

        var dir = try std.fs.openDirAbsolute(dir_path, .{});
        defer dir.close();

        const stdout = std.io.getStdOut().writer();

        const fd = std.io.getStdOut().handle;

        var last_mtime: i128 = -1;
        var last_size: u64 = 0;
        var last_w: usize = 0;
        var last_h: usize = 0;
        var first: bool = true;

        while (true) {
            const w0 = Term.getTerminalWidthOrNull(fd) orelse 80;
            const h0 = Term.getTerminalHeightOrNull(fd) orelse 24;

            // Avoid last-column wrap / tmux border clash
            const w = if (w0 > 1) w0 - 1 else w0;
            const h = h0;

            // Stat the regs file; if missing, still allow a redraw once (placeholder)
            const st_opt = dir.statFile(filename) catch null;

            const mtime: i128 = if (st_opt) |st| st.mtime else -1;
            const size: u64 = if (st_opt) |st| st.size else 0;

            const resized = (w != last_w or h != last_h);
            const changed = (mtime != last_mtime or size != last_size);

            if (first or resized or changed) {
                first = false;
                last_w = w;
                last_h = h;
                last_mtime = mtime;
                last_size = size;

                try renderOnce(alloc, stdout, dir, filename, w, h);
            }

            std.time.sleep(50_000_000); // 50ms: responsive, low CPU, no flicker
        }
    }
};

test "renderOnce prints placeholder when file missing" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var buf: [4096]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const w = fbs.writer();

    try RegsViewer.renderOnce(std.testing.allocator, w, tmp.dir, "nope.txt", 40, 10);

    const output = fbs.getWritten();

    try std.testing.expect(std.mem.startsWith(u8, output, "\x1b[2J\x1b[H"));
    try std.testing.expect(std.mem.containsAtLeast(u8, output, 1, "(waiting for registers...)"));
}

test "renderOnce prints file contents" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.writeFile(.{
        .sub_path = "regs.txt",
        .data = "X0=1 X1=2\n",
    });

    var buf: [4096]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const w = fbs.writer();

    try RegsViewer.renderOnce(std.testing.allocator, w, tmp.dir, "regs.txt", 40, 10);

    const out = fbs.getWritten();

    try std.testing.expect(std.mem.startsWith(u8, out, "\x1b[2J\x1b[H"));
    try std.testing.expect(std.mem.containsAtLeast(u8, out, 1, "X0=1 X1=2"));
}

const std = @import("std");
const Log = @import("log");
const Term = @import("term");

pub const Tui = struct {
    enabled: bool = true,
    allocator: std.mem.Allocator,
    buf: std.ArrayList(u8),
    hint_dim: bool = false,
    view: std.ArrayList(u8),

    pub fn init(allocator: std.mem.Allocator) Tui {
        return .{
            .allocator = allocator,
            .buf = std.ArrayList(u8).init(allocator),
            .view = std.ArrayList(u8).init(allocator),
        };
    }

    pub fn deinit(self: *Tui) void {
        self.buf.deinit();
        self.view.deinit();
    }

    pub fn setOutput(self: *Tui, content: []const u8) !void {
        self.buf.clearRetainingCapacity();
        try self.buf.appendSlice(content);
    }

    pub fn setView(self: *Tui, content: []const u8) !void {
        self.view.clearRetainingCapacity();
        try self.view.appendSlice(content);
    }

    pub fn output(self: *Tui) []const u8 {
        return self.buf.items;
    }

    fn hr(out: anytype, width: usize) !void {
        // width includes newline? we'll write width chars + '\n'
        // Keep a minimum so it always looks like a divider.
        const w = @max(width, 16);
        var i: usize = 0;
        while (i < w) : (i += 1) try out.writeByte('-');
        try out.writeByte('\n');
    }

    fn writeTruncatedLine(
        out: anytype,
        line: []const u8,
        width: usize,
    ) !void {
        if (width == 0) return;

        if (line.len <= width) {
            try out.writeAll(line);
            try out.writeByte('\n');
            return;
        }

        // Truncate with ellipsis when possible
        if (width <= 3) {
            try out.writeAll(line[0..width]);
            try out.writeByte('\n');
            return;
        }

        try out.writeAll(line[0..(width - 3)]);
        try out.writeAll("...");
        try out.writeByte('\n');
    }

    fn writeHintLine(out: anytype, width: usize) !void {
        const hint = "[s] step   [c] continue   [q] quit";
        try writeTruncatedLine(out, hint, width);
    }

    fn writeSectionTitle(out: anytype, title: []const u8, width: usize) !void {
        var buf: [128]u8 = undefined;
        const line = try std.fmt.bufPrint(&buf, "▶ {s}", .{title});
        try writeTruncatedLine(out, line, width);
    }

    pub fn renderWithWidth(
        self: *Tui,
        out: anytype,
        state: []const u8,
        pid: i32,
        cmd_input: []const u8,
        width_opt: ?usize,
    ) !void {
        if (!self.enabled) return;

        const width = width_opt orelse 80;

        // Header (calm, single line)
        var header_buf: [256]u8 = undefined;
        const header = try std.fmt.bufPrint(
            &header_buf,
            "dipole • {s}   pid: {d}",
            .{ state, pid },
        );
        try writeTruncatedLine(out, header, width);

        // Spacer
        try out.writeByte('\n');

        // Source view (verbatim)
        Log.log("TUI: render view_len={} status_len={}", .{ self.view.items.len, self.buf.items.len });
        if (self.view.items.len > 0) {
            try out.writeAll(self.view.items);
            if (self.view.items[self.view.items.len - 1] != '\n') try out.writeByte('\n');
        }

        // Spacer
        try out.writeByte('\n');

        // Single divider before status/footer.
        // Keep it shorter than full width so it doesn't dominate.
        try hr(out, @min(width, 48));

        // Status (verbatim)
        if (self.buf.items.len > 0) {
            try out.writeAll(self.buf.items);
            if (self.buf.items[self.buf.items.len - 1] != '\n') try out.writeByte('\n');
        }

        // Hint (quiet text)
        const hint = "step (s)  continue (c)  quit (q)";
        if (self.hint_dim) try out.writeAll("\x1b[2m");
        try writeTruncatedLine(out, hint, width);
        if (self.hint_dim) try out.writeAll("\x1b[0m");

        // Prompt
        try out.writeAll("› ");
        try out.writeAll(cmd_input);
    }

    pub fn render(
        self: *Tui,
        out: anytype,
        state: []const u8,
        pid: i32,
        cmd_input: []const u8,
    ) !void {
        const fd = std.io.getStdOut().handle;
        const width = Term.getTerminalWidthOrNull(fd);
        try self.renderWithWidth(out, state, pid, cmd_input, width);
    }
};

test "Tui can be initialized and deinitialized" {
    var tui = Tui.init(std.testing.allocator);
    defer tui.deinit();
}

test "Tui.setOutput stores content" {
    var tui = Tui.init(std.testing.allocator);
    defer tui.deinit();

    try tui.setOutput("Hello, Dipole");

    try std.testing.expect(std.mem.eql(u8, tui.output(), "Hello, Dipole"));
}

test "Tui.render emits header, body, and prompt" {
    var tui = Tui.init(std.testing.allocator);
    defer tui.deinit();

    try tui.setView("int main() {\n");
    try tui.setOutput("Stopped at main\n");

    var buf = std.ArrayList(u8).init(std.testing.allocator);
    defer buf.deinit();

    try tui.render(buf.writer(), "Stopped", 1234, "step");

    const s = buf.items;

    try std.testing.expect(std.mem.containsAtLeast(u8, s, 1, "DIPOLE"));
    try std.testing.expect(std.mem.containsAtLeast(u8, s, 1, "State: Stopped"));
    try std.testing.expect(std.mem.containsAtLeast(u8, s, 1, "PID: 1234"));
    try std.testing.expect(std.mem.containsAtLeast(u8, s, 1, "Stopped at main"));
    try std.testing.expect(std.mem.containsAtLeast(u8, s, 1, "Command> step"));
    try std.testing.expect(std.mem.containsAtLeast(u8, s, 1, "continue"));
    try std.testing.expect(std.mem.containsAtLeast(u8, s, 1, "int main()"));
    try std.testing.expect(std.mem.containsAtLeast(u8, s, 1, "Source"));
    try std.testing.expect(std.mem.containsAtLeast(u8, s, 1, "Status"));
}

test "Tui.render emits nothing when disabled" {
    var tui = Tui.init(std.testing.allocator);
    defer tui.deinit();
    tui.enabled = false;

    var buf = std.ArrayList(u8).init(std.testing.allocator);
    defer buf.deinit();

    try tui.render(buf.writer(), "Stopped", 1, "");

    try std.testing.expectEqual(@as(usize, 0), buf.items.len);
}

test "Tui.renderWithWidth uses requested rule width" {
    var tui = Tui.init(std.testing.allocator);
    defer tui.deinit();
    try tui.setOutput("X\n");

    var buf = std.ArrayList(u8).init(std.testing.allocator);
    defer buf.deinit();

    try tui.renderWithWidth(buf.writer(), "Stopped", 1, "", 10);

    // Expect at least one 10-dash rule line present.
    try std.testing.expect(std.mem.containsAtLeast(u8, buf.items, 1, "----------\n"));
}

test "writeTruncatedLine does not truncate when line fits" {
    var buf = std.ArrayList(u8).init(std.testing.allocator);
    defer buf.deinit();

    try Tui.writeTruncatedLine(buf.writer(), "HELLO", 10);
    try std.testing.expectEqualStrings("HELLO\n", buf.items);
}

test "writeTruncatedLine truncates when line exceeds width" {
    var buf = std.ArrayList(u8).init(std.testing.allocator);
    defer buf.deinit();

    try Tui.writeTruncatedLine(buf.writer(), "ABCDEFGHIJ", 8);
    try std.testing.expectEqualStrings("ABCDE...\n", buf.items);
}

test "Tui header truncates to width" {
    var tui = Tui.init(std.testing.allocator);
    defer tui.deinit();

    try tui.setOutput("X\n");

    var buf = std.ArrayList(u8).init(std.testing.allocator);
    defer buf.deinit();

    try tui.renderWithWidth(buf.writer(), "Stopped", 123456, "", 20);

    // Header must not exceed width + newline
    const first_nl = std.mem.indexOfScalar(u8, buf.items, '\n').?;
    try std.testing.expect(first_nl <= 20);
}

test "writeTruncatedLine truncates without ellipsis when width <= 3" {
    var buf = std.ArrayList(u8).init(std.testing.allocator);
    defer buf.deinit();

    try Tui.writeTruncatedLine(buf.writer(), "ABCDEFG", 3);
    try std.testing.expectEqualStrings("ABC\n", buf.items);
}

const std = @import("std");
const regs_render = @import("regs.zig");

pub const PaneFrame = struct {
    source: []u8,
    status: []u8,
    regs: []u8,

    pub fn free(self: *PaneFrame, alloc: std.mem.Allocator) void {
        alloc.free(self.source);
        alloc.free(self.status);
        alloc.free(self.regs);
        self.* = undefined;
    }
};

pub fn build(
    alloc: std.mem.Allocator,
    raw_source: []const u8,
    raw_status: []const u8,
    raw_regs: []const u8,
    width_source: usize,
    height_source: usize,
    width_status: usize,
    height_status: usize,
    width_regs: usize,
    height_regs: usize,
) !PaneFrame {
    const source_body = try renderSourcePretty(alloc, raw_source, width_source - 2, height_source - 2);
    defer alloc.free(source_body);
    const source = try renderBoxPane(alloc, "Source", source_body, width_source, height_source);

    const status_line = try extractStopReasonStatusLine(alloc, raw_status);
    defer alloc.free(status_line);

    const status_body = status_line;
    const status = try renderBoxPane(alloc, "Status", status_body, width_status, height_status);

    errdefer alloc.free(status);

    const regs = try regs_render.render(alloc, raw_regs, width_regs, height_regs);
    errdefer alloc.free(regs);

    return .{
        .source = source,
        .status = status,
        .regs = regs,
    };
}

// Simple pane renderer used for SOURCE/STATUS in v0:
// - header line (truncated to width)
// - separator line of '-' (exactly width)
// - then raw text lines, truncated to width
// - at most `height` lines total
// - newline-terminated output
fn renderSimplePane(
    alloc: std.mem.Allocator,
    title: []const u8,
    body: []const u8,
    width: usize,
    height: usize,
) ![]u8 {
    if (width == 0 or height == 0) {
        return alloc.alloc(u8, 0);
    }

    var out = std.ArrayList(u8).init(alloc);
    errdefer out.deinit();

    var lines_written: usize = 0;

    // Header
    {
        const hdr = if (title.len > width) title[0..width] else title;
        try out.appendSlice(hdr);
        try out.append('\n');
        lines_written += 1;
        if (lines_written >= height) return out.toOwnedSlice();
    }

    // Separator
    {
        try out.ensureUnusedCapacity(width + 1);
        for (0..width) |_| out.appendAssumeCapacity('-');
        out.appendAssumeCapacity('\n');
        lines_written += 1;
        if (lines_written >= height) return out.toOwnedSlice();
    }

    // Body lines
    var it = std.mem.splitScalar(u8, body, '\n');
    while (it.next()) |line| {
        if (lines_written >= height) break;
        const cleaned = std.mem.trimRight(u8, line, " \t\r");
        var truncated = if (cleaned.len > width) cleaned[0..width] else cleaned;
        truncated = std.mem.trimRight(u8, truncated, " \t\r");
        try out.appendSlice(truncated);
        try out.append('\n');
        lines_written += 1;
    }

    return out.toOwnedSlice();
}

fn renderBoxPane(
    alloc: std.mem.Allocator,
    title: []const u8,
    body: []const u8,
    width: usize,
    height: usize,
) ![]u8 {
    if (width == 0 or height == 0) return alloc.alloc(u8, 0);

    var out = std.ArrayList(u8).init(alloc);
    errdefer out.deinit();

    // Need at least 2 rows/cols for borders
    if (height < 2 or width < 2) return out.toOwnedSlice();

    const inner_w = width - 2;
    const inner_h = height - 2;

    const H = "─";
    const V = "│";

    // ┌─ title ───┐
    {
        try out.appendSlice("┌");

        var used_cols: usize = 0;

        if (inner_w > 0) {
            // Leading horizontal
            try out.appendSlice(H);
            used_cols += 1;

            if (inner_w >= 2) {
                try out.append(' ');
                used_cols += 1;

                const max_title_cols = if (inner_w > used_cols) inner_w - used_cols else 0;

                var t = title;
                if (cols(t) > max_title_cols) t = takeCols(t, max_title_cols);

                try out.appendSlice(t);
                used_cols += cols(t);
            }

            // Fill remainder with horizontals (column count)
            while (used_cols < inner_w) : (used_cols += 1) {
                try out.appendSlice(H);
            }
        }

        try out.appendSlice("┐\n");
    }

    // Body lines: │ content │
    var it = std.mem.splitScalar(u8, body, '\n');
    var row: usize = 0;

    while (row < inner_h) : (row += 1) {
        try out.appendSlice(V);

        const line = it.next() orelse "";
        const cleaned = std.mem.trimRight(u8, line, " \t\r");

        var slice = cleaned;
        if (cols(slice) > inner_w) slice = takeCols(slice, inner_w);

        try out.appendSlice(slice);

        // pad spaces by columns (ASCII spaces)
        const used = cols(slice);
        if (used < inner_w) {
            try out.ensureUnusedCapacity(inner_w - used);
            for (0..(inner_w - used)) |_| out.appendAssumeCapacity(' ');
        }

        try out.appendSlice(V);
        try out.append('\n');
    }

    // └──────────┘
    {
        try out.appendSlice("└");
        for (0..inner_w) |_| {
            try out.appendSlice(H);
        }
        try out.appendSlice("┘\n");
    }

    return out.toOwnedSlice();
}

pub fn boxSingle(
    alloc: std.mem.Allocator,
    title: []const u8,
    body: []const u8,
    width: usize,
    height: usize,
) ![]u8 {
    // Fit body to interior size. Adjust -2/-4 depending on how renderBoxPane draws.
    const inner_w = if (width > 2) width - 2 else 0;
    const inner_h = if (height > 2) height - 2 else 0;

    const fitted = try renderBodyOnly(alloc, body, inner_w, inner_h);
    defer alloc.free(fitted);

    return try renderBoxPane(alloc, title, fitted, width, height);
}

fn cols(s: []const u8) usize {
    return std.unicode.utf8CountCodepoints(s) catch s.len;
}

fn takeCols(s: []const u8, max_cols: usize) []const u8 {
    if (max_cols == 0) return s[0..0];
    var i: usize = 0;
    var n: usize = 0;
    while (i < s.len and n < max_cols) : (n += 1) {
        const clen = std.unicode.utf8ByteSequenceLength(s[i]) catch 1;
        if (i + clen > s.len) break;
        i += clen;
    }
    return s[0..i];
}

pub fn renderSourceBody(
    alloc: std.mem.Allocator,
    raw_source: []const u8,
    width: usize,
    height: usize,
) ![]u8 {
    if (width == 0 or height == 0) return alloc.alloc(u8, 0);

    var out = std.ArrayList(u8).init(alloc);
    errdefer out.deinit();

    var lines_written: usize = 0;
    var any: bool = false;

    var it = std.mem.splitScalar(u8, raw_source, '\n');
    var tmp = std.ArrayList(u8).init(alloc);
    defer tmp.deinit();

    while (it.next()) |line| {
        if (lines_written >= height) break;

        tmp.clearRetainingCapacity();
        try stripAnsiInto(&tmp, line);
        const cleaned0 = std.mem.trim(u8, tmp.items, " \t\r");
        if (cleaned0.len == 0) continue;

        // Drop obvious non-source noise
        if (std.mem.startsWith(u8, cleaned0, "Process ")) continue;

        // Drop only known non-source noise
        if (std.mem.startsWith(u8, cleaned0, "(lldb)")) continue;
        if (std.mem.eql(u8, cleaned0, "frame select 0")) continue;
        if (std.mem.eql(u8, cleaned0, "thread list")) continue;
        if (std.mem.startsWith(u8, cleaned0, "Process ")) continue;
        if (std.mem.eql(u8, cleaned0, "^")) continue;
        if (isBareLineNumber(cleaned0)) continue;

        // Drop thread summary lines
        if (std.mem.startsWith(u8, cleaned0, "* thread")) continue;

        var slice = if (cleaned0.len > width) cleaned0[0..width] else cleaned0;
        slice = std.mem.trimRight(u8, slice, " \t\r");

        try out.appendSlice(slice);
        try out.append('\n');
        lines_written += 1;
        any = true;
    }

    // Fallback: if we failed to find any “source-ish” lines, return a generic cleaned body
    if (!any) {
        out.clearRetainingCapacity();
        const fallback = try renderBodyOnly(alloc, raw_source, width, height);
        defer alloc.free(fallback);
        try out.appendSlice(fallback);
    }

    return out.toOwnedSlice();
}

pub fn renderBodyOnly(
    alloc: std.mem.Allocator,
    body: []const u8,
    width: usize,
    height: usize,
) ![]u8 {
    if (width == 0 or height == 0) return alloc.alloc(u8, 0);

    var out = std.ArrayList(u8).init(alloc);
    errdefer out.deinit();

    var lines_written: usize = 0;
    var it = std.mem.splitScalar(u8, body, '\n');

    while (it.next()) |line| {
        if (lines_written >= height) break;

        // Drop lldb prompt + blank + echoed commands (cheap + effective v0)
        const cleaned0 = std.mem.trim(u8, line, " \t\r");
        if (cleaned0.len == 0) continue;
        if (std.mem.startsWith(u8, cleaned0, "(lldb)")) continue;
        if (std.mem.eql(u8, cleaned0, "thread list")) continue;
        if (std.mem.eql(u8, cleaned0, "frame select 0")) continue;

        // Truncate, then trim trailing whitespace created by truncation cut
        var slice = if (cleaned0.len > width) cleaned0[0..width] else cleaned0;
        slice = std.mem.trimRight(u8, slice, " \t\r");

        try out.appendSlice(slice);
        try out.append('\n');
        lines_written += 1;
    }

    return out.toOwnedSlice();
}

pub fn renderSourcePretty(
    alloc: std.mem.Allocator,
    raw_source: []const u8,
    width: usize,
    height: usize,
) ![]u8 {
    if (width == 0 or height == 0) return alloc.alloc(u8, 0);

    var out = std.ArrayList(u8).init(alloc);
    errdefer out.deinit();

    var lines_written: usize = 0;

    // Pending line number state (handles the broken "bare number then code" format)
    var pending_lno: ?usize = null;
    var pending_is_current: bool = false;

    var it = std.mem.splitScalar(u8, raw_source, '\n');

    var tmp = std.ArrayList(u8).init(alloc);
    defer tmp.deinit();

    while (it.next()) |line| {
        if (lines_written >= height) break;

        tmp.clearRetainingCapacity();
        try stripAnsiInto(&tmp, line);
        const cleaned0 = std.mem.trim(u8, tmp.items, " \t\r");
        if (cleaned0.len == 0) continue;

        // Drop obvious noise
        if (std.mem.startsWith(u8, cleaned0, "(lldb)")) continue;
        if (std.mem.eql(u8, cleaned0, "thread list")) continue;
        if (std.mem.eql(u8, cleaned0, "frame select 0")) continue;
        if (std.mem.startsWith(u8, cleaned0, "Process ")) continue;
        if (std.mem.startsWith(u8, cleaned0, "* thread")) continue;

        // Drop caret-only marker lines
        if (std.mem.eql(u8, cleaned0, "^")) continue;

        // Keep frame line(s) as metadata, but don't let them consume the whole view.
        if (std.mem.startsWith(u8, cleaned0, "frame #")) {
            try appendTruncLine(&out, cleaned0, width);
            lines_written += 1;
            continue;
        }

        // 1) Arrow source row: "-> 5     code..."
        if (parseArrowSourceLine(cleaned0)) |p| {
            pending_lno = null;
            pending_is_current = false;

            // If p.text is empty, it’s the rare "-> 5" token-only format: hold pending.
            if (p.text.len == 0) {
                pending_lno = p.lno;
                pending_is_current = true;
                continue;
            }

            try emitPrettySrcLine(&out, width, true, p.lno, p.text);
            lines_written += 1;
            continue;
        }

        // 2) Bare line number token: "5"
        if (isBareLineNumber(cleaned0)) {
            pending_lno = std.fmt.parseInt(usize, cleaned0, 10) catch null;
            pending_is_current = false;
            continue;
        }

        // 3) Normal numbered source row: "5     code..."
        if (parseNumberedSourceLine(cleaned0)) |p2| {
            pending_lno = null;
            pending_is_current = false;

            // If it’s number-only (shouldn't happen if isBareLineNumber caught it),
            // just treat as pending.
            if (p2.text.len == 0) {
                pending_lno = p2.lno;
                pending_is_current = false;
                continue;
            }

            try emitPrettySrcLine(&out, width, false, p2.lno, p2.text);
            lines_written += 1;
            continue;
        }

        // 4) Otherwise: if we have a pending line number, pair it with this code line.
        if (pending_lno) |lno| {
            try emitPrettySrcLine(&out, width, pending_is_current, lno, cleaned0);
            lines_written += 1;
            pending_lno = null;
            pending_is_current = false;
            continue;
        }

        // 5) Fallback: emit as-is (rare, but keeps you from losing potentially useful lines).
        try appendTruncLine(&out, cleaned0, width);
        lines_written += 1;
    }

    return out.toOwnedSlice();
}

// ---------- helpers (private) ----------

const Parsed = struct {
    lno: usize,
    text: []const u8, // may be empty for token-only forms
};

fn parseArrowSourceLine(s: []const u8) ?Parsed {
    var i: usize = 0;
    while (i < s.len and (s[i] == ' ' or s[i] == '\t')) : (i += 1) {}
    if (i + 1 >= s.len) return null;
    if (s[i] != '-' or s[i + 1] != '>') return null;
    i += 2;
    while (i < s.len and (s[i] == ' ' or s[i] == '\t')) : (i += 1) {}
    if (i >= s.len or !isDigit(s[i])) return null;

    const start = i;
    while (i < s.len and isDigit(s[i])) : (i += 1) {}
    const lno = std.fmt.parseInt(usize, s[start..i], 10) catch return null;

    while (i < s.len and (s[i] == ' ' or s[i] == '\t')) : (i += 1) {}
    const text = if (i < s.len) std.mem.trimRight(u8, s[i..], " \t\r") else s[0..0];

    return .{ .lno = lno, .text = text };
}

fn parseNumberedSourceLine(s: []const u8) ?Parsed {
    var i: usize = 0;
    while (i < s.len and (s[i] == ' ' or s[i] == '\t')) : (i += 1) {}
    if (i >= s.len or !isDigit(s[i])) return null;

    const start = i;
    while (i < s.len and isDigit(s[i])) : (i += 1) {}
    const lno = std.fmt.parseInt(usize, s[start..i], 10) catch return null;

    // require at least some whitespace between number and text to count as "numbered source"
    const ws_start = i;
    while (i < s.len and (s[i] == ' ' or s[i] == '\t')) : (i += 1) {}
    if (ws_start == i) return null;

    const text = if (i < s.len) std.mem.trimRight(u8, s[i..], " \t\r") else s[0..0];
    return .{ .lno = lno, .text = text };
}

fn emitPrettySrcLine(
    out: *std.ArrayList(u8),
    width: usize,
    is_current: bool,
    lno: usize,
    text: []const u8,
) !void {
    const arrow = if (is_current) "› " else "  ";

    // fixed 4-wide line numbers
    var prefix_buf: [64]u8 = undefined;
    const prefix = try std.fmt.bufPrint(&prefix_buf, "{s}{d:>3} │ ", .{ arrow, lno });

    const rem: usize = if (width > prefix.len) width - prefix.len else 0;
    var body = std.mem.trimRight(u8, text, " \t\r");
    if (body.len > rem) body = body[0..rem];

    try out.appendSlice(prefix);
    try out.appendSlice(body);
    try out.append('\n');
}

fn appendTruncLine(out: *std.ArrayList(u8), line: []const u8, width: usize) !void {
    if (width == 0) return;
    var slice = std.mem.trimRight(u8, line, " \t\r");
    if (slice.len > width) slice = slice[0..width];
    slice = std.mem.trimRight(u8, slice, " \t\r");
    try out.appendSlice(slice);
    try out.append('\n');
}

pub fn extractStopReasonStatusLine(
    alloc: std.mem.Allocator,
    raw_status: []const u8,
) ![]u8 {
    var it = std.mem.splitScalar(u8, raw_status, '\n');
    while (it.next()) |line| {
        if (std.mem.indexOf(u8, line, "stop reason") != null) {
            const idx = std.mem.indexOf(u8, line, "stop reason").?;
            const tail = line[idx..];
            return std.fmt.allocPrint(alloc, "{s}", .{tail});
        }
    }

    // fallback
    return std.fmt.allocPrint(alloc, "stop reason: (unknown)", .{});
}

fn stripAnsiInto(out: *std.ArrayList(u8), line: []const u8) !void {
    var i: usize = 0;
    while (i < line.len) {
        const c = line[i];

        if (c == 0x1b) { // ESC
            // Handle CSI escape: ESC '[' ... final-byte
            if (i + 1 < line.len and line[i + 1] == '[') {
                i += 2; // consume ESC[
                while (i < line.len) : (i += 1) {
                    const d = line[i];
                    // final byte in 0x40..0x7E terminates CSI
                    if (d >= 0x40 and d <= 0x7E) {
                        i += 1; // consume final byte
                        break;
                    }
                }
                continue;
            }

            // Unknown escape: drop ESC and continue
            i += 1;
            continue;
        }

        try out.append(c);
        i += 1;
    }
}

fn isBareLineNumber(s: []const u8) bool {
    const t = std.mem.trim(u8, s, " \t\r");
    if (t.len == 0) return false;
    for (t) |c| {
        if (c < '0' or c > '9') return false;
    }
    return true;
}

fn isDigit(c: u8) bool {
    return c >= '0' and c <= '9';
}

fn startsWithArrowLineNumber(s: []const u8) bool {
    var i: usize = 0;
    while (i < s.len and (s[i] == ' ' or s[i] == '\t')) : (i += 1) {}
    if (i + 1 >= s.len) return false;
    if (s[i] != '-' or s[i + 1] != '>') return false;
    i += 2;
    while (i < s.len and (s[i] == ' ' or s[i] == '\t')) : (i += 1) {}
    return i < s.len and isDigit(s[i]);
}

fn looksLikeSourceLine(line: []const u8) bool {
    const t = std.mem.trim(u8, line, " \t\r");
    if (t.len == 0) return false;

    if (std.mem.startsWith(u8, t, "frame #")) return true;
    if (startsWithArrowLineNumber(t)) return true;

    // starts with a line number
    var i: usize = 0;
    while (i < t.len and (t[i] == ' ' or t[i] == '\t')) : (i += 1) {}
    return i < t.len and isDigit(t[i]);
}

fn expectPaneShape(pane: []const u8, title: []const u8, width: usize, height: usize) !void {
    var lines_it = std.mem.splitScalar(u8, pane, '\n');

    const l1 = lines_it.next() orelse return error.MissingHeader;
    try std.testing.expectEqualStrings(title, l1);

    const l2 = lines_it.next() orelse return error.MissingRule;
    try std.testing.expectEqual(@as(usize, width), l2.len);
    for (l2) |c| try std.testing.expectEqual(@as(u8, '-'), c);

    var count: usize = 2;
    while (lines_it.next()) |ln| {
        if (ln.len == 0 and lines_it.peek() == null) break; // last empty from trailing '\n'
        try std.testing.expect(ln.len <= width);
        count += 1;
    }
    try std.testing.expect(count <= height);
}

test "PaneFrame build truncates and uses regs renderer" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const raw_source =
        \\frame #0: 0x0000000100000460 args`main at args.c:12:3
        \\12   printf("hello world");
        \\13   return 0;
    ;

    const raw_status =
        \\Process 123 stopped
        \\* thread #1, stop reason = breakpoint 1.1
        \\  frame #0: ...
    ;

    const raw_regs =
        \\x0 = 0x0000000000000001
        \\x1 = 0x0000000000000002
        \\x2 = 0x0000000000000003
    ;

    var frame = try build(
        alloc,
        raw_source,
        raw_status,
        raw_regs,
        16,
        4, // source width/height
        18,
        3, // status width/height
        20,
        4, // regs width/height
    );
    defer frame.free(alloc);

    const expected_source =
        \\┌─ Source──────┐
        \\│frame #0: 0x00│
        \\│   12 │ prin  │
        \\└──────────────┘
        \\
    ;

    try std.testing.expectEqualStrings(expected_source, frame.source);

    const expected_status =
        \\┌─ Status────────┐
        \\│stop reason = br│
        \\└────────────────┘
        \\
    ;

    try std.testing.expectEqualStrings(expected_status, frame.status);

    // REGS should come from regs renderer (header + sep + 2 lines)
    const expected_regs =
        \\REGISTERS
        \\--------------------
        \\x0 = 0x0000000000000
        \\x1 = 0x0000000000000
        \\
    ;
    try std.testing.expectEqualStrings(expected_regs, frame.regs);
}

test "renderBodyOnly filters lldb prompts and echoed commands" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const input =
        \\thread list
        \\Process 123 stopped
        \\* thread #1, stop reason = breakpoint 1.1
        \\(lldb)
        \\(lldb)   ^
        \\frame #0: 0x0000000100000460 simple`main at simple.c:6:5
        \\
    ;

    const out = try renderBodyOnly(alloc, input, 200, 10);
    defer alloc.free(out);

    // Should not include prompts or echoed commands.
    try std.testing.expect(std.mem.indexOf(u8, out, "(lldb)") == null);
    try std.testing.expect(std.mem.indexOf(u8, out, "thread list") == null);

    // Should keep actual content lines.
    try std.testing.expect(std.mem.indexOf(u8, out, "Process 123 stopped") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "stop reason") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "frame #0:") != null);
}

test "renderSourceBody prefers frame+line-number source and drops process/thread noise" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const input =
        \\Process 123 stopped
        \\* thread #1, stop reason = breakpoint 1.1
        \\frame #0: 0x0000000100000600 simple`main at simple.c:6:5
        \\   5    int x = 1;
        \\   6    x += 1;
        \\   7    }
        \\(lldb)
    ;

    const out = try renderSourceBody(alloc, input, 200, 10);
    defer alloc.free(out);

    try std.testing.expect(std.mem.indexOf(u8, out, "Process") == null);
    try std.testing.expect(std.mem.indexOf(u8, out, "* thread") == null);

    try std.testing.expect(std.mem.indexOf(u8, out, "frame #0:") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "6    x += 1;") != null);
}

test "renderSourceBody keeps ANSI-colored line numbers and arrow current line" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const input =
        \\frame #0: 0x0000 simple`main at simple.c:5:5
        \\\x1b[32m2\x1b[0m
        \\int main(void)
        \\\x1b[32m3\x1b[0m
        \\{
        \\-> 5     printf("Hello world!");
        \\\x1b[32m6\x1b[0m
        \\return 0;
        \\\x1b[32m7\x1b[0m
        \\}
        \\(lldb)
    ;

    const out = try renderSourceBody(alloc, input, 200, 20);
    defer alloc.free(out);

    try std.testing.expect(std.mem.indexOf(u8, out, "frame #0:") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "int main") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "-> 5") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "(lldb)") == null);
}

test "stripAnsiInto preserves digits around SGR codes" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var out = std.ArrayList(u8).init(alloc);
    defer out.deinit();

    try stripAnsiInto(&out, "\x1b[32m3\x1b[0m");
    try std.testing.expectEqualStrings("3", out.items);
}

test "renderSourcePretty formats inline arrow listing into fixed grid" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const input =
        \\Process 57918 stopped
        \\* thread #1, stop reason = breakpoint 1.1
        \\  frame #0: 0x00000001000005f0 simple`main at simple.c:5:5
        \\2
        \\3     int main(void)
        \\4     {
        \\-> 5     printf("Hello world!");
        \\6     return 0;
        \\7     }
        \\(lldb)
        \\
    ;

    const out = try renderSourcePretty(alloc, input, 200, 20);
    defer alloc.free(out);

    // Noise removed
    try std.testing.expect(std.mem.indexOf(u8, out, "Process ") == null);
    try std.testing.expect(std.mem.indexOf(u8, out, "* thread") == null);
    try std.testing.expect(std.mem.indexOf(u8, out, "(lldb)") == null);

    // Frame kept
    try std.testing.expect(std.mem.containsAtLeast(u8, out, 1, "frame #0:"));

    // Fixed-grid lines present (new glyphs)
    try std.testing.expect(std.mem.containsAtLeast(u8, out, 1, "  3 │ int main(void)"));
    try std.testing.expect(std.mem.containsAtLeast(u8, out, 1, "  4 │ {"));
    try std.testing.expect(std.mem.containsAtLeast(u8, out, 1, "›   5 │ printf(\"Hello world!\");"));
    try std.testing.expect(std.mem.containsAtLeast(u8, out, 1, "  6 │ return 0;"));
    try std.testing.expect(std.mem.containsAtLeast(u8, out, 1, "  7 │ }"));
}

test "renderSourcePretty pairs bare number tokens and drops caret-only marker" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const input =
        \\frame #0: 0x0000 exit_0_c`main at exit_0.c:4:5
        \\1
        \\// Scenario 1 - Clean Exit
        \\2
        \\3
        \\int main() {
        \\-> 4
        \\return 0;
        \\^
        \\5
        \\}
        \\
    ;

    const out = try renderSourcePretty(alloc, input, 200, 20);
    defer alloc.free(out);

    //std.debug.print("OUT:\n{s}\n", .{out});

    // Bare number tokens should not appear as standalone lines anymore
    try std.testing.expect(std.mem.indexOf(u8, out, "\n1\n") == null);
    try std.testing.expect(std.mem.indexOf(u8, out, "\n2\n") == null);
    try std.testing.expect(std.mem.indexOf(u8, out, "\n3\n") == null);
    try std.testing.expect(std.mem.indexOf(u8, out, "\n5\n") == null);

    // Paired/normalized output exists
    try std.testing.expect(std.mem.containsAtLeast(u8, out, 1, "    1 │ // Scenario 1 - Clean Exit"));
    try std.testing.expect(std.mem.containsAtLeast(u8, out, 1, "    3 │ int main() {"));
    try std.testing.expect(std.mem.containsAtLeast(u8, out, 1, "›   4 │ return 0;"));
    try std.testing.expect(std.mem.containsAtLeast(u8, out, 1, "    5 │ }"));

    // Caret-only marker must be dropped
    try std.testing.expect(std.mem.indexOf(u8, out, "\n^\n") == null);
}

test "renderSourcePretty strips ANSI and still parses numbered/arrow lines" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const input =
        "frame #0: 0x0000 simple`main at simple.c:5:5\n" ++
        "\x1b[32m3\x1b[0m     int main(void)\n" ++
        "\x1b[32m4\x1b[0m     {\n" ++
        "-> \x1b[32m5\x1b[0m     return 0;\n";

    const out = try renderSourcePretty(alloc, input, 200, 20);
    defer alloc.free(out);

    // No raw escape bytes should remain
    try std.testing.expect(std.mem.indexOfScalar(u8, out, 0x1b) == null);

    // Lines still parsed
    try std.testing.expect(std.mem.containsAtLeast(u8, out, 1, "    3 │ int main(void)"));
    try std.testing.expect(std.mem.containsAtLeast(u8, out, 1, "    4 │ {"));
    try std.testing.expect(std.mem.containsAtLeast(u8, out, 1, "›   5 │ return 0;"));
}

test "renderSourcePretty respects width and height" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const input =
        \\frame #0: 0x0000 simple`main at simple.c:5:5
        \\3     int main(void)
        \\4     { this is a very very very long line that should be truncated
        \\-> 5     printf("Hello world!");
        \\6     return 0;
        \\7     }
        \\
    ;

    // Tiny width/height to stress truncation
    const out = try renderSourcePretty(alloc, input, 16, 3);
    defer alloc.free(out);

    //std.debug.print("OUT:\n{s}\n", .{out});

    // Ensure at most 3 lines (each ends with '\n', last also)
    var count: usize = 0;
    for (out) |c| {
        if (c == '\n') count += 1;
    }
    try std.testing.expect(count <= 3);

    // Ensure no line exceeds width (excluding '\n')
    var it = std.mem.splitScalar(u8, out, '\n');
    while (it.next()) |ln| {
        if (ln.len == 0 and it.peek() == null) break;
        try std.testing.expect(ln.len <= 16);
    }
}

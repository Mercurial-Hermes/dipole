const std = @import("std");

pub fn render(
    alloc: std.mem.Allocator,
    regs_text: []const u8,
    width: usize,
    height: usize,
) ![]u8 {
    if (height == 0 or width == 0) {
        return alloc.alloc(u8, 0);
    }

    var out = std.ArrayList(u8).init(alloc);
    errdefer out.deinit();

    var lines_written: usize = 0;

    // Line 1: Header
    {
        const header = "REGISTERS";
        const hdr = if (header.len > width) header[0..width] else header;
        try out.appendSlice(hdr);
        try out.append('\n');
        lines_written += 1;
        if (lines_written >= height) return out.toOwnedSlice();
    }

    // Line 2: Separator
    {
        try out.ensureUnusedCapacity(width + 1);
        for (0..width) |_| out.appendAssumeCapacity('-');
        out.appendAssumeCapacity('\n');
        lines_written += 1;
        if (lines_written >= height) return out.toOwnedSlice();
    }

    // Remaining lines: regs text (split + truncate)
    var it = std.mem.splitScalar(u8, regs_text, '\n');
    while (it.next()) |line| {
        if (lines_written >= height) break;

        const truncated = if (line.len > width) line[0..width] else line;
        try out.appendSlice(truncated);
        try out.append('\n');
        lines_written += 1;
    }

    return out.toOwnedSlice();
}

test "Regs renderer basic layout and truncation" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const input =
        \\x0 = 0x0000000000000001
        \\x1 = 0x0000000000000002
        \\x2 = 0x0000000000000003
    ;

    const out = try render(alloc, input, 20, 4);
    defer alloc.free(out);

    const expected =
        \\REGISTERS
        \\--------------------
        \\x0 = 0x0000000000000
        \\x1 = 0x0000000000000
        \\
    ;

    try std.testing.expectEqualStrings(expected, out);
}

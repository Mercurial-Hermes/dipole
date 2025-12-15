const std = @import("std");

pub const Esc = "\x1b";

pub fn clearHome(writer: anytype) !void {
    // Cursor to home + clear screen
    try writer.writeAll(Esc ++ "[H" ++ Esc ++ "[2J");
}

pub fn hideCursor(writer: anytype) !void {
    try writer.writeAll(Esc ++ "[?25l");
}

pub fn showCursor(writer: anytype) !void {
    try writer.writeAll(Esc ++ "[?25h");
}

// Optional style helpers (nice for later)
pub fn reset(writer: anytype) !void {
    try writer.writeAll(Esc ++ "[0m");
}

pub fn bold(writer: anytype) !void {
    try writer.writeAll(Esc ++ "[1m");
}

pub fn dim(writer: anytype) !void {
    try writer.writeAll(Esc ++ "[2m");
}

pub fn faint(out: anytype) !void {
    try out.writeAll("\x1b[2m");
}

test "ansi.clearHome emits home+clear" {
    var buf = std.ArrayList(u8).init(std.testing.allocator);
    defer buf.deinit();

    try clearHome(buf.writer());
    try std.testing.expectEqualStrings("\x1b[H\x1b[2J", buf.items);
}

test "ansi.hideCursor emits DEC private mode hide cursor" {
    var buf = std.ArrayList(u8).init(std.testing.allocator);
    defer buf.deinit();

    try hideCursor(buf.writer());
    try std.testing.expectEqualStrings("\x1b[?25l", buf.items);
}

test "ansi.showCursor emits DEC private mode show cursor" {
    var buf = std.ArrayList(u8).init(std.testing.allocator);
    defer buf.deinit();

    try showCursor(buf.writer());
    try std.testing.expectEqualStrings("\x1b[?25h", buf.items);
}

test "ansi.style helpers" {
    var buf = std.ArrayList(u8).init(std.testing.allocator);
    defer buf.deinit();

    try bold(buf.writer());
    try dim(buf.writer());
    try reset(buf.writer());

    try std.testing.expectEqualStrings("\x1b[1m\x1b[2m\x1b[0m", buf.items);
}

test "ansi faint emits escape code" {
    var buf = std.ArrayList(u8).init(std.testing.allocator);
    defer buf.deinit();
    try faint(buf.writer());
    try std.testing.expectEqualStrings("\x1b[2m", buf.items);
}

// Scenario 1 — Clean Exit (return code 42)
const std = @import("std");

pub fn main() !void {
    std.process.exit(42);
}

const std = @import("std");
const LLDBDriver = @import("lib").LLDBDriver;

pub fn main() !void {
    const gpa = std.heap.page_allocator;
    var stdout = std.io.getStdOut().writer();
    var stdin = std.io.getStdIn().reader();

    try stdout.print("Dipole REPL — Experiment 0.7\n", .{});
    try stdout.print("Type 'quit' to exit.\n\n", .{});

    // For the REPL demo, launch lldb without a target.
    var driver = try LLDBDriver.initAttach(gpa, 0);
    defer driver.deinit();

    // Wait for LLDB banner + initial prompt.
    _ = try driver.waitForPrompt();

    // Main REPL loop
    var line_buffer: [512]u8 = undefined;

    while (true) {
        try stdout.print("dipole> ", .{});
        const line = (try stdin.readUntilDelimiterOrEof(&line_buffer, '\n')) orelse continue;

        if (line.len == 0) continue;

        if (std.mem.eql(u8, line, "quit")) {
            break;
        }

        // Send command to LLDB (no newline needed; sendLine adds it)
        try driver.sendLine(line);

        // Read LLDB output
        const out = driver.readUntilPrompt(.LldbPrompt) catch |err| switch (err) {
            error.PromptTimeout => {
                try stdout.print("Timeout: interrupting target…\n", .{});
                try driver.sendLine("process interrupt");

                const interrupted = try driver.readUntilPrompt(.LldbPrompt);
                try stdout.print("{s}\n", .{interrupted});
                continue; // go back to REPL loop
            },
            else => return err,
        };

        // Print result
        try stdout.print("{s}", .{out});
    }

    try stdout.print("\nShutting down LLDB…\n", .{});
    try driver.shutdown();
}

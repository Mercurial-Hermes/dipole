const std = @import("std");
const RegisterFile = @import("RegisterFile.zig").RegisterFile;
const Log = @import("log");

pub const REPL = struct {
    /// Commands the REPL understands
    pub const Command = union(enum) {
        Step,
        Next,
        Continue,
        Backtrace,
        Regs,
        Quit,
        Invalid,
        Raw: []const u8,
        Shell: []const u8,
    };

    fn splitPath(
        full_path: []const u8,
    ) !struct { dir: std.fs.Dir, name: []const u8 } {
        const slash = std.mem.lastIndexOfScalar(u8, full_path, '/') orelse return error.InvalidPath;

        const dir_path = full_path[0..slash];
        const filename = full_path[slash + 1 ..];

        const dir = try std.fs.openDirAbsolute(dir_path, .{});
        // filename is a borrowed slice; ok.

        return .{ .dir = dir, .name = filename };
    }

    pub fn readUserInput(
        alloc: std.mem.Allocator,
        reader: anytype,
    ) ![]u8 {
        var list = std.ArrayList(u8).init(alloc);
        errdefer list.deinit();

        var buf: [1]u8 = undefined;

        while (true) {
            Log.log("readUserInput: about to enter reader.read()", .{});
            const n = try reader.read(&buf);
            Log.log("readUserInput: reader.read returned n={}", .{n});
            if (n == 0) break; // EOF
            if (buf[0] == '\n') break;

            try list.append(buf[0]);
        }

        return list.toOwnedSlice();
    }

    /// Parse a raw input line into a Command
    pub fn parseCommand(line: []const u8) Command {
        const trimmed = std.mem.trim(u8, line, " \t\r\n");

        if (trimmed.len == 0) return .Invalid;

        // Exact single-letter or short commands
        if (std.mem.eql(u8, trimmed, "s") or std.mem.eql(u8, trimmed, "step"))
            return .Step;

        if (std.mem.eql(u8, trimmed, "n") or std.mem.eql(u8, trimmed, "next"))
            return .Next;

        if (std.mem.eql(u8, trimmed, "c") or std.mem.eql(u8, trimmed, "continue"))
            return .Continue;

        if (std.mem.eql(u8, trimmed, "bt"))
            return .Backtrace;

        if (std.mem.eql(u8, trimmed, "regs") or std.mem.eql(u8, trimmed, "rg"))
            return .Regs;

        if (std.mem.eql(u8, trimmed, "q") or std.mem.eql(u8, trimmed, "quit"))
            return .Quit;

        // Raw LLDB command: lldb <rest>
        if (std.mem.startsWith(u8, trimmed, "lldb ")) {
            return Command{ .Raw = trimmed["lldb ".len..] };
        }
        // Shell escape: !<cmd>
        if (trimmed[0] == '!') {
            if (trimmed.len == 1) return .Invalid;
            return Command{ .Shell = trimmed[1..] };
        }

        // Default
        return .Invalid;
    }

    pub const ExecResult = struct {
        keep_going: bool,
        out: ?[]u8 = null, // owned; caller frees
    };

    pub fn execute(
        driver: anytype,
        cmd: Command,
        alloc: std.mem.Allocator,
        reg_path: []const u8,
    ) !ExecResult {
        switch (cmd) {
            .Step => {
                try driver.sendLine("step");
                const txt = try driver.readUntilPrompt(.LldbPrompt);
                return .{ .keep_going = true, .out = try alloc.dupe(u8, txt) };
            },
            .Next => {
                try driver.sendLine("next");
                const txt = try driver.readUntilPrompt(.LldbPrompt);
                return .{ .keep_going = true, .out = try alloc.dupe(u8, txt) };
            },
            .Continue => {
                try driver.sendLine("continue");
                const txt = try driver.readUntilPrompt(.LldbPrompt);
                return .{ .keep_going = true, .out = try alloc.dupe(u8, txt) };
            },
            .Backtrace => {
                try driver.sendLine("bt");
                const txt = try driver.readUntilPrompt(.LldbPrompt);
                return .{ .keep_going = true, .out = try alloc.dupe(u8, txt) };
            },
            .Raw => |raw_cmd| {
                try driver.sendLine(raw_cmd);
                const txt = try driver.readUntilPrompt(.LldbPrompt);
                return .{ .keep_going = true, .out = try alloc.dupe(u8, txt) };
            },
            .Regs => {
                try driver.sendLine("register read");
                const out = try driver.readUntilPrompt(.LldbPrompt);

                var parts = try splitPath(reg_path);
                defer parts.dir.close();

                try RegisterFile.writeAt(parts.dir, parts.name, out);

                return .{ .keep_going = true, .out = try alloc.dupe(u8, out) };
            },
            .Shell => |shell_cmd| {
                Log.log("REPL: executing shell cmd: '{s}'", .{shell_cmd});

                var child = std.process.Child.init(&.{ "bash", "-lc", shell_cmd }, alloc);
                child.stdin_behavior = .Ignore;
                child.stdout_behavior = .Pipe;
                child.stderr_behavior = .Pipe;

                try child.spawn();

                const out = try child.stdout.?.reader().readAllAlloc(alloc, 64 * 1024);
                defer alloc.free(out);

                const err = try child.stderr.?.reader().readAllAlloc(alloc, 64 * 1024);
                defer alloc.free(err);

                _ = try child.wait();

                // Combine stdout + stderr into one owned buffer for the TUI.
                var buf = std.ArrayList(u8).init(alloc);
                errdefer buf.deinit();

                if (out.len != 0) try buf.appendSlice(out);
                if (err.len != 0) {
                    if (buf.items.len != 0 and buf.items[buf.items.len - 1] != '\n')
                        try buf.append('\n');
                    try buf.appendSlice(err);
                }

                // Always end with newline so Status panel looks tidy.
                if (buf.items.len != 0 and buf.items[buf.items.len - 1] != '\n')
                    try buf.append('\n');

                return .{ .keep_going = true, .out = try buf.toOwnedSlice() };
            },
            .Quit => return .{ .keep_going = false, .out = null },
            else => return .{ .keep_going = true, .out = null },
        }
    }

    /// The full REPL loop (production only)
    pub fn run(
        driver: anytype,
        alloc: std.mem.Allocator,
        reg_path: []const u8,
    ) !void {
        _ = driver;
        _ = alloc;
        _ = reg_path;
        return error.TODO;
    }
};

const FakeDriver = struct {
    allocator: std.mem.Allocator,
    sent: std.ArrayList([]const u8),
    output: []const u8 = "OK",

    pub fn init(alloc: std.mem.Allocator) FakeDriver {
        return .{ .allocator = alloc, .sent = std.ArrayList([]const u8).init(alloc) };
    }
    pub fn deinit(self: *FakeDriver) void {
        self.sent.deinit();
    }

    pub fn sendLine(self: *FakeDriver, line: []const u8) !void {
        try self.sent.append(line);
    }

    pub fn readUntilPrompt(self: *FakeDriver, prompt: anytype) ![]const u8 {
        _ = prompt;
        return self.output;
    }
};

test "parseCommand: step forms" {
    try std.testing.expectEqual(REPL.Command.Step, REPL.parseCommand("s"));
    try std.testing.expectEqual(REPL.Command.Step, REPL.parseCommand("step"));
}

test "parseCommand: next forms" {
    try std.testing.expectEqual(REPL.Command.Next, REPL.parseCommand("n"));
    try std.testing.expectEqual(REPL.Command.Next, REPL.parseCommand("next"));
}

test "parseCommand: continue forms" {
    try std.testing.expectEqual(REPL.Command.Continue, REPL.parseCommand("c"));
    try std.testing.expectEqual(REPL.Command.Continue, REPL.parseCommand("continue"));
}

test "parseCommand: regs" {
    try std.testing.expectEqual(REPL.Command.Regs, REPL.parseCommand("regs"));
    try std.testing.expectEqual(REPL.Command.Regs, REPL.parseCommand("rg"));
}

test "parseCommand: backtrace" {
    try std.testing.expectEqual(REPL.Command.Backtrace, REPL.parseCommand("bt"));
}

test "parseCommand: quit forms" {
    try std.testing.expectEqual(REPL.Command.Quit, REPL.parseCommand("q"));
    try std.testing.expectEqual(REPL.Command.Quit, REPL.parseCommand("quit"));
}

test "parseCommand: raw lldb commands" {
    const cmd = REPL.parseCommand("lldb frame info");
    switch (cmd) {
        .Raw => |s| try std.testing.expectEqualStrings("frame info", s),
        else => return error.TestExpectedEqual,
    }
}

test "parseCommand: invalid" {
    try std.testing.expectEqual(REPL.Command.Invalid, REPL.parseCommand("??"));
    try std.testing.expectEqual(REPL.Command.Invalid, REPL.parseCommand(""));
}

test "execute: Step -> sends 'step' to driver and returns transcript" {
    const gpa = std.testing.allocator;
    var driver = FakeDriver.init(gpa);
    defer driver.deinit();

    const res = try REPL.execute(
        &driver,
        REPL.Command.Step,
        gpa,
        "/tmp/does-not-matter",
    );
    defer if (res.out) |o| gpa.free(o);

    try std.testing.expect(res.keep_going == true);

    // command was sent
    try std.testing.expectEqual(@as(usize, 1), driver.sent.items.len);
    try std.testing.expectEqualStrings("step", driver.sent.items[0]);

    // transcript returned
    try std.testing.expect(res.out != null);
    try std.testing.expect(std.mem.containsAtLeast(u8, res.out.?, 1, "OK"));
}

test "execute: step sends step to driver" {
    const gpa = std.testing.allocator;
    var driver = FakeDriver.init(gpa);
    defer driver.deinit();

    const res = try REPL.execute(
        &driver,
        .Step,
        gpa,
        "/ignored",
    );
    defer if (res.out) |o| gpa.free(o);

    // 1. We should keep looping
    try std.testing.expect(res.keep_going == true);

    // 2. Driver should have received a "step" command
    try std.testing.expectEqual(@as(usize, 1), driver.sent.items.len);
    try std.testing.expectEqualStrings("step", driver.sent.items[0]);

    // 3. We should have a transcript to show in the TUI
    try std.testing.expect(res.out != null);
    try std.testing.expect(std.mem.containsAtLeast(u8, res.out.?, 1, "OK"));
}

test "execute: Next -> sends 'next' to driver and continues loop" {
    const gpa = std.testing.allocator;
    var driver = FakeDriver.init(gpa);
    defer driver.deinit();

    const res = try REPL.execute(
        &driver,
        REPL.Command.Next,
        gpa,
        "/tmp/does-not-matter",
    );
    defer if (res.out) |o| gpa.free(o);

    try std.testing.expect(res.keep_going == true);
    try std.testing.expectEqual(@as(usize, 1), driver.sent.items.len);
    try std.testing.expectEqualStrings("next", driver.sent.items[0]);

    try std.testing.expect(res.out != null);
    try std.testing.expect(std.mem.containsAtLeast(u8, res.out.?, 1, "OK"));
}

test "execute: Continue -> sends 'continue' to driver and continues loop" {
    const gpa = std.testing.allocator;
    var driver = FakeDriver.init(gpa);
    defer driver.deinit();

    const res = try REPL.execute(
        &driver,
        REPL.Command.Continue,
        gpa,
        "/tmp/ignore",
    );
    defer if (res.out) |o| gpa.free(o);

    try std.testing.expect(res.keep_going == true);
    try std.testing.expectEqual(@as(usize, 1), driver.sent.items.len);
    try std.testing.expectEqualStrings("continue", driver.sent.items[0]);

    try std.testing.expect(res.out != null);
    try std.testing.expect(std.mem.containsAtLeast(u8, res.out.?, 1, "OK"));
}

test "execute: Backtrace -> sends 'bt' to driver and continues loop" {
    const gpa = std.testing.allocator;
    var driver = FakeDriver.init(gpa);
    defer driver.deinit();

    const res = try REPL.execute(
        &driver,
        REPL.Command.Backtrace,
        gpa,
        "/tmp/ignore",
    );
    defer if (res.out) |o| gpa.free(o);

    try std.testing.expect(res.keep_going == true);
    try std.testing.expectEqual(@as(usize, 1), driver.sent.items.len);
    try std.testing.expectEqualStrings("bt", driver.sent.items[0]);

    try std.testing.expect(res.out != null);
    try std.testing.expect(std.mem.containsAtLeast(u8, res.out.?, 1, "OK"));
}

test "execute: Raw LLDB -> sends command string to driver and continues loop" {
    const gpa = std.testing.allocator;
    var driver = FakeDriver.init(gpa);
    defer driver.deinit();

    const res = try REPL.execute(
        &driver,
        REPL.Command{ .Raw = "frame info" },
        gpa,
        "/tmp/ignore",
    );
    defer if (res.out) |o| gpa.free(o);

    try std.testing.expect(res.keep_going == true);
    try std.testing.expectEqual(@as(usize, 1), driver.sent.items.len);
    try std.testing.expectEqualStrings("frame info", driver.sent.items[0]);

    try std.testing.expect(res.out != null);
    try std.testing.expect(std.mem.containsAtLeast(u8, res.out.?, 1, "OK"));
}

test "execute: Regs -> writes register snapshot via RegisterFile" {
    const gpa = std.testing.allocator;
    var driver = FakeDriver.init(gpa);
    defer driver.deinit();

    // Fake LLDB output
    driver.output = "X0=1 X1=2\n";

    // Make a temporary directory
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    // Absolute path to the temp dir
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const abs_dir = try tmp.dir.realpath(".", &buf);

    // Full path to regs.txt
    const path = try std.fs.path.join(gpa, &[_][]const u8{
        abs_dir,
        "regs.txt",
    });
    defer gpa.free(path);

    // Execute REPL command
    const res = try REPL.execute(
        &driver,
        REPL.Command.Regs,
        gpa,
        path,
    );
    defer if (res.out) |o| gpa.free(o);

    try std.testing.expect(res.keep_going == true);

    // Regs should explicitly ask LLDB for registers
    try std.testing.expectEqual(@as(usize, 1), driver.sent.items.len);
    try std.testing.expectEqualStrings("register read", driver.sent.items[0]);

    // Verify the file contains the fake driver output
    var f = try std.fs.openFileAbsolute(path, .{});
    defer f.close();

    var buf2: [128]u8 = undefined;
    const n = try f.read(&buf2);
    const written = buf2[0..n];

    try std.testing.expectEqualStrings("X0=1 X1=2\n", written);

    // And we should return transcript for the TUI
    try std.testing.expect(res.out != null);
    try std.testing.expectEqualStrings("X0=1 X1=2\n", res.out.?);
}

test "execute: Quit -> returns keep_going=false, sends no commands" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var driver = FakeDriver.init(gpa.allocator());
    defer driver.deinit();

    const res = try REPL.execute(
        &driver,
        .Quit,
        gpa.allocator(),
        "/tmp/dipole_regs.txt",
    );
    defer if (res.out) |o| gpa.allocator().free(o);

    // Quit should tell the loop to stop
    try std.testing.expect(!res.keep_going);

    // Quit should not return output
    try std.testing.expect(res.out == null);

    // No commands should have been sent
    try std.testing.expectEqual(@as(usize, 0), driver.sent.items.len);
}

test "readUserInput reads one line" {
    const alloc = std.testing.allocator;

    const input = "hello world\nignored stuff";
    var stream = std.io.fixedBufferStream(input);

    const line = try REPL.readUserInput(alloc, stream.reader());
    defer alloc.free(line);

    try std.testing.expectEqualStrings("hello world", line);
}

test "readUserInput handles EOF without newline" {
    const alloc = std.testing.allocator;

    var stream = std.io.fixedBufferStream("lastline");
    const line = try REPL.readUserInput(alloc, stream.reader());
    defer alloc.free(line);

    try std.testing.expectEqualStrings("lastline", line);
}

test "execute: Shell returns output" {
    const gpa = std.testing.allocator;
    var driver = FakeDriver.init(gpa);
    defer driver.deinit();

    const res = try REPL.execute(&driver, .{ .Shell = "echo hi" }, gpa, "/ignored");
    defer if (res.out) |o| gpa.free(o);

    try std.testing.expect(res.keep_going);
    try std.testing.expect(res.out != null);
    try std.testing.expect(std.mem.containsAtLeast(u8, res.out.?, 1, "hi"));
}

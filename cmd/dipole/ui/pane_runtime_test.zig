// cmd/dipole/ui/pane_runtime_test.zig

const std = @import("std");
const pane_runtime = @import("pane_runtime");
const request_envelope = @import("request_envelope");
const controller = @import("controller");

test "pane role parsing accepts repl and output" {
    try std.testing.expectEqual(pane_runtime.PaneRole.repl, pane_runtime.parsePaneRole("repl").?);
    try std.testing.expectEqual(pane_runtime.PaneRole.output, pane_runtime.parsePaneRole("output").?);
}

test "pane role parsing rejects unknown roles" {
    try std.testing.expect(pane_runtime.parsePaneRole("") == null);
    try std.testing.expect(pane_runtime.parsePaneRole("regs") == null);
    try std.testing.expect(pane_runtime.parsePaneRole("REPL") == null);
}

test "repl parser maps commands to lldb strings" {
    const alloc = std.testing.allocator;
    const step_cmd = (try pane_runtime.parseReplLine(alloc, "step")).?.command;
    defer alloc.free(step_cmd);
    try std.testing.expectEqualStrings("thread step-in\n", step_cmd);

    const next_cmd = (try pane_runtime.parseReplLine(alloc, "next")).?.command;
    defer alloc.free(next_cmd);
    try std.testing.expectEqualStrings("thread step-over\n", next_cmd);

    const cont_cmd = (try pane_runtime.parseReplLine(alloc, "continue")).?.command;
    defer alloc.free(cont_cmd);
    try std.testing.expectEqualStrings("process continue\n", cont_cmd);
}

test "repl parser maps breakpoint file:line" {
    const alloc = std.testing.allocator;
    const bp_cmd = (try pane_runtime.parseReplLine(alloc, "breakpoint main.c:42")).?.command;
    defer alloc.free(bp_cmd);
    try std.testing.expectEqualStrings("breakpoint set --file main.c --line 42\n", bp_cmd);
}

test "repl parser handles quit" {
    const action = try pane_runtime.parseReplLine(std.testing.allocator, "q");
    try std.testing.expect(action != null);
    try std.testing.expect(action.? == .quit);
}

test "controller and transport do not expose pane roles" {
    comptime {
        try std.testing.expect(!@hasDecl(controller, "PaneRole"));
        try std.testing.expect(!@hasDecl(request_envelope, "PaneRole"));
    }
}

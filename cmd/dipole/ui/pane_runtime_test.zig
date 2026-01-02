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

fn captureEnvelopeBytes(payload: []const u8) ![]u8 {
    var fds = try std.posix.pipe();
    defer {
        if (fds[0] >= 0) _ = std.posix.close(fds[0]);
        if (fds[1] >= 0) _ = std.posix.close(fds[1]);
    }
    try request_envelope.writeEnvelope(fds[1], 1, payload);
    _ = std.posix.close(fds[1]);
    fds[1] = -1;

    const total_len = 8 + payload.len;
    const buf = try std.testing.allocator.alloc(u8, total_len);
    errdefer std.testing.allocator.free(buf);
    const ok = try request_envelope.readExact(fds[0], buf);
    try std.testing.expect(ok);
    return buf;
}

test "envelope payload bytes invariant across pane roles" {
    const payload = "help\n";
    const bytes_repl = try captureEnvelopeBytes(payload);
    defer std.testing.allocator.free(bytes_repl);
    const bytes_output = try captureEnvelopeBytes(payload);
    defer std.testing.allocator.free(bytes_output);
    try std.testing.expectEqualSlices(u8, bytes_repl, bytes_output);
}

test "controller and transport do not expose pane roles" {
    comptime {
        try std.testing.expect(!@hasDecl(controller, "PaneRole"));
        try std.testing.expect(!@hasDecl(request_envelope, "PaneRole"));
    }
}

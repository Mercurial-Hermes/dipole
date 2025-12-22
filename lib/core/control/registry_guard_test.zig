const std = @import("std");
const reg = @import("semantic_registry");
const event_kind = @import("event_kind");

// NOTE: This test intentionally snapshots the TS3 registry.
// Any change here requires an explicit semantic slice, not TS4.
test "TS4-900-001: TS4 introduces no new semantic meaning" {
    // Snapshot the registry shape expected from TS3 plus allowed TS4 opaque snapshot projections.
    const expected = [_]struct {
        name: []const u8,
        version: ?reg.SemanticVersion,
        permitted: []const reg.EventField,
    }{
        .{
            .name = "event.kind",
            .version = null,
            .permitted = &.{.category},
        },
        .{
            .name = "event.kind",
            .version = .{ .major = 1, .minor = 0 },
            .permitted = &.{.category},
        },
        .{
            .name = "breakpoint.list",
            .version = .{ .major = 1, .minor = 0 },
            .permitted = &.{.category},
        },
        .{
            .name = "register.snapshot",
            .version = .{ .major = 1, .minor = 0 },
            .permitted = &.{.category},
        },
    };

    try std.testing.expectEqual(@as(usize, expected.len), reg.registry.projections.len);
    try std.testing.expectEqual(@as(usize, expected.len), reg.registry.meta.len);

    inline for (expected, 0..) |exp, i| {
        const def = reg.registry.projections[i];
        try std.testing.expectEqualStrings(exp.name, def.id.name);
        try std.testing.expectEqual(exp.version, def.id.version);
        try std.testing.expectEqual(exp.permitted.len, def.permitted_fields.len);
        inline for (exp.permitted, 0..) |pf, j| {
            try std.testing.expectEqual(pf, def.permitted_fields[j]);
        }
        // TS4-900-001: breakpoint.list@1.0 and register.snapshot@1.0 are permitted as opaque snapshot projections (no new semantic meaning).
        if (std.mem.eql(u8, exp.name, "breakpoint.list") or std.mem.eql(u8, exp.name, "register.snapshot")) {
            try std.testing.expect(def.output_kind == []const u8);
        } else {
            try std.testing.expectEqual(event_kind.EventKind, def.output_kind);
        }

        const meta = reg.registry.meta[i];
        try std.testing.expectEqualStrings(exp.name, meta.name);
        try std.testing.expectEqual(exp.version, meta.version);
    }
}

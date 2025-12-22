const std = @import("std");
const reg = @import("semantic_registry");
const event_kind = @import("event_kind");

// NOTE: This test intentionally snapshots the TS3 registry.
// Any change here requires an explicit semantic slice, not TS4.
test "TS4-900-001: TS4 introduces no new semantic meaning" {
    // Snapshot the registry shape expected from TS3 (projection ids + permitted_fields).
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
        try std.testing.expectEqual(event_kind.EventKind, def.output_kind);

        const meta = reg.registry.meta[i];
        try std.testing.expectEqualStrings(exp.name, meta.name);
        try std.testing.expectEqual(exp.version, meta.version);
    }
}

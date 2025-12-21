const std = @import("std");
const semantic_show = @import("semantic_show");

test "TS3-001-002: show without explicit version fails with ERR_MISSING_VERSION" {
    try std.testing.expectError(error.MissingVersion, semantic_show.run(std.testing.allocator, "event.kind"));

    const info = semantic_show.errorInfo(error.MissingVersion).?;
    try std.testing.expectEqualStrings("ERR_MISSING_VERSION", info.token);
    try std.testing.expectEqual(@as(u8, 2), info.exit_code);
}

test "TS3-001-002: invalid selector forms" {
    try std.testing.expectError(error.InvalidSelector, semantic_show.run(std.testing.allocator, ""));
    try std.testing.expectError(error.MissingVersion, semantic_show.run(std.testing.allocator, "event.kind@"));
    try std.testing.expectError(error.InvalidSelector, semantic_show.run(std.testing.allocator, "@1.0"));
    try std.testing.expectError(error.InvalidSelector, semantic_show.run(std.testing.allocator, "event.kind@v"));
}

test "TS3-001-002: unknown id vs unknown version" {
    try std.testing.expectError(error.UnknownProjectionId, semantic_show.run(std.testing.allocator, "does.not.exist@1.0"));
    try std.testing.expectError(error.UnknownVersion, semantic_show.run(std.testing.allocator, "event.kind@9.9"));
}

test "TS3-001-002: explicit version accepted and returns NotImplemented placeholder" {
    try std.testing.expectError(error.NotImplemented, semantic_show.run(std.testing.allocator, "event.kind@1.0"));
    try std.testing.expectError(error.NotImplemented, semantic_show.run(std.testing.allocator, "event.kind@1"));
}

test "TS3-001-004: unknown ProjectionId fails safely with ERR_UNKNOWN_PROJECTION_ID" {
    try std.testing.expectError(error.UnknownProjectionId, semantic_show.run(std.testing.allocator, "does.not.exist@1.0"));

    const info = semantic_show.errorInfo(error.UnknownProjectionId).?;
    try std.testing.expectEqualStrings("ERR_UNKNOWN_PROJECTION_ID", info.token);
    try std.testing.expect(info.exit_code != 0);
}

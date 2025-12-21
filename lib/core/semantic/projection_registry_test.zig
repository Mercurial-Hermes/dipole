const std = @import("std");
const reg = @import("registry.zig");

fn versionsEqual(a: ?reg.SemanticVersion, b: ?reg.SemanticVersion) bool {
    if (a == null and b == null) return true;
    if (a == null or b == null) return false;
    return a.?.major == b.?.major and a.?.minor == b.?.minor;
}

// Enforced at comptime to guarantee the registry remains
// a static, unambiguous catalogue of semantic meaning.
fn expectUniqueProjectionIds(registry: *const reg.ProjectionRegistry) !void {
    comptime var i: usize = 0;
    inline while (i < registry.projections.len) : (i += 1) {
        const a = registry.projections[i];
        comptime var j: usize = i + 1;
        inline while (j < registry.projections.len) : (j += 1) {
            const b = registry.projections[j];
            const same_name = std.mem.eql(u8, a.id.name, b.id.name);
            const same_version = versionsEqual(a.id.version, b.id.version);
            if (same_name and same_version) {
                return error.DuplicateProjectionId;
            }
        }
    }
}

fn isAllowedTS2Field(field: reg.EventField) bool {
    return switch (field) {
        .category,
        .event_id,
        => true,
    };
}

fn expectOnlyAllowedEventFields(fields: []const reg.EventField) !void {
    for (fields) |f| {
        if (!isAllowedTS2Field(f)) {
            return error.InvalidPermittedField;
        }
    }
}

test "TS2-002: registry contains declared projection" {
    const id = reg.ProjectionId{ .name = "event.kind" };

    const def1 = reg.registry.lookup(id);
    const def2 = reg.registry.lookup(id);

    try std.testing.expect(def1 != null);
    try std.testing.expect(def1 == def2);
}

test "TS2-002: ProjectionDef is pure declarative data" {
    comptime {
        switch (@typeInfo(reg.ProjectionDef)) {
            .@"struct" => |info| {
                for (info.fields) |field| {
                    const field_info = @typeInfo(field.type);

                    switch (field_info) {
                        .@"fn" => @compileError("ProjectionDef must not contain function fields"),
                        .pointer => |p| {
                            // Const pointers (e.g. slices to static data) are permitted.
                            // Mutable pointers would allow runtime state or behaviour to leak in.
                            if (!p.is_const) {
                                @compileError("ProjectionDef must not contain pointers to mutable state");
                            }
                        },
                        else => {},
                    }

                    if (field.type == std.mem.Allocator) {
                        @compileError("ProjectionDef must not contain allocators");
                    }
                }
            },
            else => @compileError("ProjectionDef must be a struct"),
        }
    }
}

test "TS2-002: projection names are unique" {
    try expectUniqueProjectionIds(&reg.registry);
}

test "TS2-002: unversioned and versioned projections may coexist" {
    try std.testing.expect(reg.registry.lookup(.{ .name = "event.kind" }) != null);
    try std.testing.expect(reg.registry.lookup(.{
        .name = "event.kind",
        .version = .{ .major = 1, .minor = 0 },
    }) != null);
}

// Enforced at comptime to guarantee that every semantic projection
// explicitly declares a valid TS2 dependency surface.
test "TS2-002: projection definitions declare permitted fields explicitly" {
    comptime {
        var i: usize = 0;
        while (i < reg.registry.projections.len) : (i += 1) {
            const def = reg.registry.projections[i];

            if (def.permitted_fields.len == 0) {
                @compileError("permitted_fields must not be empty");
            }

            var j: usize = 0;
            while (j < def.permitted_fields.len) : (j += 1) {
                const f = def.permitted_fields[j];
                if (!isAllowedTS2Field(f)) {
                    @compileError("permitted_fields contains non-TS2-allowed field");
                }
            }
        }
    }
}

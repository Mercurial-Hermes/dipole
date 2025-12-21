const std = @import("std");
const EventKind = @import("event_kind.zig").EventKind;

pub const SemanticVersion = struct {
    major: u16,
    minor: u16,
};

pub const ProjectionId = struct {
    /// Stable semantic identifier (dot-separated, lowercase).
    name: []const u8,
    /// Optional semantic version.
    version: ?SemanticVersion = null,
};

/// Enumerates event fields permitted for semantic dependence.
/// This list is intentionally minimal and expanded only by explicit TS work.
pub const EventField = enum {
    category,
    event_id,
};

pub const ProjectionDef = struct {
    id: ProjectionId,
    description: []const u8,
    output_kind: type,
    permitted_fields: []const EventField,
};

pub const ProjectionRegistry = struct {
    projections: []const ProjectionDef,

    pub fn lookup(self: *const ProjectionRegistry, id: ProjectionId) ?*const ProjectionDef {
        for (self.projections) |*p| {
            if (!std.mem.eql(u8, p.id.name, id.name)) continue;

            const a = p.id.version;
            const b = id.version;
            if (versionsEqual(a, b)) return p;
        }
        return null;
    }

    fn versionsEqual(a: ?SemanticVersion, b: ?SemanticVersion) bool {
        if (a == null and b == null) return true;
        if (a == null or b == null) return false;
        const av = a.?;
        const bv = b.?;
        return av.major == bv.major and av.minor == bv.minor;
    }
};

const projections = [_]ProjectionDef{
    .{
        .id = .{ .name = "event.kind" },
        .description = "Semantic classification of events",
        .output_kind = EventKind,
        .permitted_fields = &.{.category},
    },
    .{
        .id = .{
            .name = "event.kind",
            .version = .{ .major = 1, .minor = 0 },
        },
        .description = "Semantic classification of events (explicitly versioned)",
        .output_kind = EventKind,
        .permitted_fields = &.{.category},
    },
};

pub const registry = ProjectionRegistry{
    .projections = &projections,
};

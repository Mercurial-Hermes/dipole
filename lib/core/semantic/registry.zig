const std = @import("std");
const EventKind = @import("event_kind").EventKind;

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

pub fn eventFieldName(f: EventField) []const u8 {
    return switch (f) {
        .category => "category",
        .event_id => "event_id",
    };
}

pub const ProjectionDef = struct {
    id: ProjectionId,
    description: []const u8,
    output_kind: type,
    permitted_fields: []const EventField,
};

pub const ProjectionMeta = struct {
    name: []const u8,
    version: ?SemanticVersion,
};

pub const ProjectionRegistry = struct {
    projections: []const ProjectionDef,
    meta: []const ProjectionMeta,

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

    pub fn exists(self: *const ProjectionRegistry, id: ProjectionId) bool {
        for (self.meta) |m| {
            if (!std.mem.eql(u8, m.name, id.name)) continue;
            if (versionsEqual(m.version, id.version)) return true;
        }
        return false;
    }

    pub fn nameExists(self: *const ProjectionRegistry, name: []const u8) bool {
        for (self.meta) |m| {
            if (std.mem.eql(u8, m.name, name)) return true;
        }
        return false;
    }

    pub fn nameHasMultiple(self: *const ProjectionRegistry, name: []const u8) bool {
        var count: usize = 0;
        for (self.meta) |m| {
            if (std.mem.eql(u8, m.name, name)) {
                count += 1;
                if (count > 1) return true;
            }
        }
        return false;
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

const projection_meta = blk: {
    var items: [projections.len]ProjectionMeta = undefined;
    for (projections, 0..) |def, i| {
        items[i] = .{ .name = def.id.name, .version = def.id.version };
    }
    break :blk items;
};

pub const registry = ProjectionRegistry{
    .projections = &projections,
    .meta = &projection_meta,
};

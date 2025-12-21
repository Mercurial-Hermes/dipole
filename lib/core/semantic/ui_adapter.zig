const std = @import("std");
const reg = @import("registry.zig");

/// Frame view presented to UI adapters.
/// Derived meaning only: projection id, version, and canonical payload bytes.
/// Canonical derived payload bytes (already semantic; interpretation is UI-local).
pub const Frame = struct {
    projection_id: []const u8,
    /// Null version represents an explicitly unversioned projection identity.
    version: ?reg.SemanticVersion,
    payload: []const u8,
};

/// Minimal render model: structured strings only.
pub const RenderOutput = struct {
    title: []const u8,
    sections: []const Section,
};

pub const Section = struct {
    title: ?[]const u8 = null,
    rows: []const Row,
};

pub const Row = struct {
    label: []const u8,
    value: []const u8,
};

pub const UiAdapter = struct {
    projection_id: reg.ProjectionId,

    pub const Error = error{
        ProjectionIdMismatch,
        OutOfMemory,
    };

    fn versionsEqual(a: ?reg.SemanticVersion, b: ?reg.SemanticVersion) bool {
        if (a == null and b == null) return true;
        if (a == null or b == null) return false;
        const av = a.?;
        const bv = b.?;
        return av.major == bv.major and av.minor == bv.minor;
    }

    pub fn render(self: UiAdapter, alloc: std.mem.Allocator, frame: Frame) Error!RenderOutput {
        if (!std.mem.eql(u8, self.projection_id.name, frame.projection_id) or
            !versionsEqual(self.projection_id.version, frame.version))
        {
            return error.ProjectionIdMismatch;
        }

        // Adapter renders derived meaning; no semantic computation performed.
        const rows = try alloc.alloc(Row, 1);
        errdefer alloc.free(rows);
        rows[0] = .{ .label = "payload", .value = frame.payload };

        const sections = try alloc.alloc(Section, 1);
        errdefer alloc.free(sections);
        sections[0] = .{ .title = null, .rows = rows };

        return RenderOutput{
            .title = frame.projection_id,
            .sections = sections,
        };
    }
};

/// title borrows frame.projection_id; caller must ensure frame lifetime ≥ RenderOutput
pub fn deinitRenderOutput(alloc: std.mem.Allocator, out: *RenderOutput) void {
    for (out.sections) |s| {
        alloc.free(s.rows);
    }
    alloc.free(out.sections);
    out.* = RenderOutput{
        .title = &.{},
        .sections = &.{},
    };
}

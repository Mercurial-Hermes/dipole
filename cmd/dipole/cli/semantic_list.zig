const std = @import("std");
const reg = @import("semantic_registry");

fn versionLessThan(a: ?reg.SemanticVersion, b: ?reg.SemanticVersion) bool {
    // Sort by (name, version) with null-before-explicit, then major, then minor.
    if (a == null) return b != null; // null versions sort before explicit versions
    if (b == null) return false;
    const av = a.?;
    const bv = b.?;
    if (av.major != bv.major) return av.major < bv.major;
    return av.minor < bv.minor;
}

const ProjectionListItem = struct {
    name: []const u8,
    version: ?reg.SemanticVersion,
    permitted_fields: []const reg.EventField,
};

fn projectionLessThanItem(a: ProjectionListItem, b: ProjectionListItem) bool {
    const name_cmp = std.mem.order(u8, a.name, b.name);
    if (name_cmp == .lt) return true;
    if (name_cmp == .gt) return false;
    return versionLessThan(a.version, b.version);
}

fn projectionLessThanContext(_: void, a: ProjectionListItem, b: ProjectionListItem) bool {
    return projectionLessThanItem(a, b);
}

fn sortedProjections(alloc: std.mem.Allocator) ![]ProjectionListItem {
    var items = try alloc.alloc(ProjectionListItem, reg.registry.projections.len);
    errdefer alloc.free(items);

    inline for (reg.registry.projections, 0..) |def, i| {
        items[i] = .{
            .name = def.id.name,
            .version = def.id.version,
            .permitted_fields = def.permitted_fields,
        };
    }

    std.sort.pdq(ProjectionListItem, items, {}, projectionLessThanContext);
    return items;
}

fn writeEscapedString(w: anytype, s: []const u8) !void {
    try w.writeByte('"');
    for (s) |c| {
        switch (c) {
            '"' => try w.writeAll("\\\""),
            '\\' => try w.writeAll("\\\\"),
            '\n' => try w.writeAll("\\n"),
            '\r' => try w.writeAll("\\r"),
            '\t' => try w.writeAll("\\t"),
            0x08 => try w.writeAll("\\b"),
            0x0C => try w.writeAll("\\f"),
            else => {
                if (c < 0x20) {
                    try w.writeAll("\\u00");
                    const hi = "0123456789abcdef"[(c >> 4) & 0xF];
                    const lo = "0123456789abcdef"[c & 0xF];
                    try w.writeByte(hi);
                    try w.writeByte(lo);
                } else {
                    try w.writeByte(c);
                }
            },
        }
    }
    try w.writeByte('"');
}

fn writeProjection(w: anytype, item: ProjectionListItem) !void {
    try w.writeByte('{');

    // Keys sorted lexicographically: permitted_fields, projection_id, version.
    try w.writeAll("\"permitted_fields\":[");
    for (item.permitted_fields, 0..) |f, i| {
        if (i != 0) try w.writeByte(',');
        try writeEscapedString(w, reg.eventFieldName(f));
    }
    try w.writeAll("],\"projection_id\":");
    try writeEscapedString(w, item.name);
    try w.writeAll(",\"version\":");
    if (item.version) |v| {
        try w.writeAll("{\"major\":");
        try std.fmt.formatInt(v.major, 10, .lower, .{}, w);
        try w.writeAll(",\"minor\":");
        try std.fmt.formatInt(v.minor, 10, .lower, .{}, w);
        try w.writeByte('}');
    } else {
        try w.writeAll("null");
    }

    try w.writeByte('}');
}

/// Returns canonical JSON bytes describing registered projections.
/// Caller owns the returned slice.
pub fn listProjections(alloc: std.mem.Allocator) ![]u8 {
    const projections = try sortedProjections(alloc);
    defer alloc.free(projections);

    var out = std.ArrayList(u8).init(alloc);
    errdefer out.deinit();
    const w = out.writer();

    try w.writeByte('[');
    for (projections, 0..) |p, i| {
        if (i != 0) try w.writeByte(',');
        try writeProjection(w, p);
    }
    try w.writeByte(']');

    return out.toOwnedSlice();
}

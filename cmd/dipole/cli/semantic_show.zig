const std = @import("std");
const reg = @import("semantic_registry");

pub const ShowError = error{
    MissingVersion,
    InvalidSelector,
    UnknownProjectionId,
    UnknownVersion,
    NotImplemented,
};

pub const ErrorInfo = struct {
    token: []const u8,
    exit_code: u8,
};

pub fn errorInfo(err: ShowError) ?ErrorInfo {
    return switch (err) {
        error.MissingVersion => .{ .token = "ERR_MISSING_VERSION", .exit_code = 2 },
        error.InvalidSelector => .{ .token = "ERR_INVALID_SELECTOR", .exit_code = 2 },
        error.UnknownProjectionId => .{ .token = "ERR_UNKNOWN_PROJECTION_ID", .exit_code = 3 },
        error.UnknownVersion => .{ .token = "ERR_UNKNOWN_VERSION", .exit_code = 3 },
        error.NotImplemented => .{ .token = "ERR_SHOW_NOT_IMPLEMENTED", .exit_code = 1 },
    };
}

const ParsedSelector = struct {
    name: []const u8,
    version: reg.SemanticVersion,
};

const ProjectionMeta = struct {
    name: []const u8,
    version: ?reg.SemanticVersion,
};

const projection_meta = blk: {
    var items: [reg.registry.projections.len]ProjectionMeta = undefined;
    for (reg.registry.projections, 0..) |def, i| {
        items[i] = .{
            .name = def.id.name,
            .version = def.id.version,
        };
    }
    break :blk items;
};

fn parseVersionDigits(s: []const u8) !reg.SemanticVersion {
    if (s.len == 0) return error.MissingVersion;

    var parts = std.mem.splitScalar(u8, s, '.');
    const major_str = parts.next() orelse return error.MissingVersion;
    const major = std.fmt.parseUnsigned(u16, major_str, 10) catch {
        return error.InvalidSelector;
    };
    const minor_str = parts.next();
    if (minor_str) |ms| {
        const minor = std.fmt.parseUnsigned(u16, ms, 10) catch {
            return error.InvalidSelector;
        };
        if (parts.next() != null) return error.InvalidSelector;
        return .{ .major = major, .minor = minor };
    }
    return .{ .major = major, .minor = 0 };
}

fn parseSelector(selector: []const u8) !ParsedSelector {
    if (selector.len == 0) return error.InvalidSelector;
    const at_pos = std.mem.indexOfScalar(u8, selector, '@') orelse return error.MissingVersion;
    if (at_pos == 0) return error.InvalidSelector;
    const name = selector[0..at_pos];
    if (name.len == 0) return error.InvalidSelector;
    const version_part_raw = selector[at_pos + 1 ..];
    if (version_part_raw.len == 0) return error.MissingVersion;

    const version_part = if (version_part_raw[0] == 'v' or version_part_raw[0] == 'V')
        version_part_raw[1..]
    else
        version_part_raw;
    if (version_part.len == 0) return error.InvalidSelector;

    const version = try parseVersionDigits(version_part);
    return .{ .name = name, .version = version };
}

fn lookupVersionStatus(sel: ParsedSelector) ShowError!void {
    const id = reg.ProjectionId{ .name = sel.name, .version = sel.version };
    if (reg.registry.exists(id)) return;
    if (reg.registry.nameExists(sel.name)) return error.UnknownVersion;
    return error.UnknownProjectionId;
}

/// CLI-facing handler for `semantic show`. Returns NotImplemented on success path to
/// keep TS3-001-002 focused on argument/selection validation.
pub fn run(alloc: std.mem.Allocator, selector: []const u8) ShowError![]u8 {
    _ = alloc; // currently unused; reserved for future payloads
    const sel = try parseSelector(selector);
    try lookupVersionStatus(sel);
    return error.NotImplemented;
}

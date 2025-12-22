const std = @import("std");
const reg = @import("semantic_registry");
const proj = @import("projection");
const ev = @import("event");

pub const EvalError = error{
    MissingVersion,
    InvalidSelector,
    UnknownProjectionId,
    UnknownVersion,
    MissingLogPath,
    InvalidLogFormat,
    UnsupportedProjection,
    OutOfMemory,
};

pub const ErrorInfo = struct {
    token: []const u8,
    exit_code: u8,
};

pub fn errorInfo(err: EvalError) ?ErrorInfo {
    return switch (err) {
        error.MissingVersion => .{ .token = "ERR_MISSING_VERSION", .exit_code = 2 },
        error.InvalidSelector => .{ .token = "ERR_INVALID_SELECTOR", .exit_code = 2 },
        error.MissingLogPath => .{ .token = "ERR_MISSING_LOG", .exit_code = 2 },
        error.UnknownProjectionId => .{ .token = "ERR_UNKNOWN_PROJECTION_ID", .exit_code = 3 },
        error.UnknownVersion => .{ .token = "ERR_UNKNOWN_VERSION", .exit_code = 3 },
        error.InvalidLogFormat => .{ .token = "ERR_INVALID_LOG_FORMAT", .exit_code = 1 },
        error.UnsupportedProjection => .{ .token = "ERR_UNSUPPORTED_PROJECTION", .exit_code = 1 },
        error.OutOfMemory => .{ .token = "ERR_ALLOC_FAILED", .exit_code = 1 },
    };
}

const ParsedSelector = struct {
    name: []const u8,
    version: reg.SemanticVersion,
};

fn parseVersionDigits(s: []const u8) !reg.SemanticVersion {
    if (s.len == 0) return error.MissingVersion;
    var parts = std.mem.splitScalar(u8, s, '.');
    const major_str = parts.next() orelse return error.MissingVersion;
    const major = std.fmt.parseUnsigned(u16, major_str, 10) catch return error.InvalidSelector;
    const minor_str = parts.next();
    if (minor_str) |ms| {
        const minor = std.fmt.parseUnsigned(u16, ms, 10) catch return error.InvalidSelector;
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

fn ensureProjectionExists(sel: ParsedSelector) EvalError!void {
    const id = reg.ProjectionId{ .name = sel.name, .version = sel.version };
    if (reg.registry.exists(id)) return;
    if (reg.registry.nameExists(sel.name)) return error.UnknownVersion;
    return error.UnknownProjectionId;
}

fn parseCategory(line: []const u8) !ev.Category {
    return std.meta.stringToEnum(ev.Category, line) orelse return error.InvalidLogFormat;
}

fn readLog(alloc: std.mem.Allocator, path: []const u8) ![]ev.Event {
    if (path.len == 0) return error.MissingLogPath;
    const contents = std.fs.cwd().readFileAlloc(alloc, path, std.math.maxInt(usize)) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return error.InvalidLogFormat,
    };
    defer alloc.free(contents);

    var list = std.ArrayList(ev.Event).init(alloc);
    errdefer list.deinit();

    var idx: usize = 0;
    var it = std.mem.splitScalar(u8, contents, '\n');
    while (it.next()) |line_raw| {
        const line = std.mem.trim(u8, line_raw, " \t\r");
        if (line.len == 0) continue;
        const cat = try parseCategory(line);
        try list.append(.{
            .category = cat,
            .event_id = idx,
            .timestamp = null,
        });
        idx += 1;
    }

    return list.toOwnedSlice();
}

fn serializeEventKindsCanonical(kinds: []const proj.EventKind, buf: *std.ArrayList(u8)) ![]const u8 {
    try buf.append('[');
    for (kinds, 0..) |k, i| {
        if (i != 0) try buf.append(',');
        const s = switch (k) {
            .SessionLifecycle => "SessionLifecycle",
            .UserAction => "UserAction",
            .EngineActivity => "EngineActivity",
            .Snapshot => "Snapshot",
            .Unknown => "Unknown",
        };
        try buf.append('"');
        try buf.appendSlice(s);
        try buf.append('"');
    }
    try buf.append(']');
    return buf.items;
}

pub fn eval(alloc: std.mem.Allocator, selector: []const u8, log_path: []const u8) EvalError![]u8 {
    const sel = try parseSelector(selector);
    try ensureProjectionExists(sel);

    const events = try readLog(alloc, log_path);
    defer alloc.free(events);

    if (std.mem.eql(u8, sel.name, "event.kind")) {
        const kinds = try proj.projectEventKinds(alloc, events);
        defer alloc.free(kinds);

        var buf = std.ArrayList(u8).init(alloc);
        errdefer buf.deinit();
        _ = try serializeEventKindsCanonical(kinds, &buf);
        return buf.toOwnedSlice();
    }

    return error.UnsupportedProjection;
}

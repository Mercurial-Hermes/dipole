const std = @import("std");
const reg = @import("semantic_registry");
const feed = @import("semantic_feed");
const ui = @import("ui_adapter");
const ev = @import("event");

pub const RenderError = error{
    MissingVersion,
    InvalidSelector,
    MissingLogPath,
    InvalidLogFormat,
    UnknownProjectionId,
    UnknownVersion,
    ProjectionIdMismatch,
    UnsupportedProjection,
    OutOfMemory,
};

pub const ErrorInfo = struct {
    token: []const u8,
    exit_code: u8,
};

pub fn errorInfo(err: RenderError) ?ErrorInfo {
    return switch (err) {
        error.MissingVersion => .{ .token = "ERR_MISSING_VERSION", .exit_code = 2 },
        error.InvalidSelector => .{ .token = "ERR_INVALID_SELECTOR", .exit_code = 2 },
        error.MissingLogPath => .{ .token = "ERR_MISSING_LOG", .exit_code = 2 },
        error.UnknownProjectionId => .{ .token = "ERR_UNKNOWN_PROJECTION_ID", .exit_code = 3 },
        error.UnknownVersion => .{ .token = "ERR_UNKNOWN_VERSION", .exit_code = 3 },
        error.InvalidLogFormat => .{ .token = "ERR_INVALID_LOG_FORMAT", .exit_code = 1 },
        error.ProjectionIdMismatch => .{ .token = "ERR_PROJECTION_ID_MISMATCH", .exit_code = 1 },
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

fn ensureProjectionExists(sel: ParsedSelector) RenderError!void {
    const id = reg.ProjectionId{ .name = sel.name, .version = sel.version };
    if (reg.registry.exists(id)) return;
    if (reg.registry.nameExists(sel.name)) return error.UnknownVersion;
    return error.UnknownProjectionId;
}

fn parseCategory(line: []const u8) !ev.Category {
    return std.meta.stringToEnum(ev.Category, line) orelse return error.InvalidLogFormat;
}

const LoadedLog = struct {
    events: []ev.Event,
    backing: []u8,
};

fn readLog(alloc: std.mem.Allocator, path: []const u8) !LoadedLog {
    if (path.len == 0) return error.MissingLogPath;
    const contents = std.fs.cwd().readFileAlloc(alloc, path, std.math.maxInt(usize)) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return error.InvalidLogFormat,
    };

    var list = std.ArrayList(ev.Event).init(alloc);
    errdefer list.deinit();

    var idx: usize = 0;
    var it = std.mem.splitScalar(u8, contents, '\n');
    while (it.next()) |line_raw| {
        const line = std.mem.trim(u8, line_raw, " \t\r");
        if (line.len == 0) continue;
        const payload_split = std.mem.indexOfScalar(u8, line, ':');
        const cat_str = if (payload_split) |p| line[0..p] else line;
        const payload = if (payload_split) |p| line[p + 1 ..] else &.{}; // payload bytes after ':', may be empty
        const cat = try parseCategory(cat_str);
        try list.append(.{
            .category = cat,
            .event_id = idx,
            .timestamp = null,
            .payload = payload,
        });
        idx += 1;
    }

    return .{ .events = try list.toOwnedSlice(), .backing = contents };
}

pub fn render(alloc: std.mem.Allocator, selector: []const u8, log_path: []const u8) RenderError![]u8 {
    const sel = try parseSelector(selector);
    try ensureProjectionExists(sel);

    const loaded = try readLog(alloc, log_path);
    defer {
        alloc.free(loaded.events);
        alloc.free(loaded.backing);
    }

    const id = reg.ProjectionId{ .name = sel.name, .version = sel.version };
    var frame = try feed.buildFrame(alloc, id, loaded.events);
    defer feed.deinitFrame(alloc, &frame);

    const adapter = ui.UiAdapter{ .projection_id = id };
    var out = try adapter.render(alloc, .{
        .projection_id = frame.projection_id,
        .version = frame.version,
        .payload = frame.payload,
    });
    defer ui.deinitRenderOutput(alloc, &out);

    if (out.sections.len == 0 or out.sections[0].rows.len == 0) return error.ProjectionIdMismatch;
    const payload_bytes = out.sections[0].rows[0].value;
    return alloc.dupe(u8, payload_bytes);
}

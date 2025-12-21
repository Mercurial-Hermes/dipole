const std = @import("std");
const reg = @import("registry.zig");
const proj = @import("projection.zig");
const ev = @import("event");

pub const FeedError = error{
    UnknownProjectionId,
    UnknownVersion,
    UnsupportedProjection,
    InvalidSelector,
    OutOfMemory,
};

pub const Frame = struct {
    projection_id: []u8,
    // Null version represents an explicitly unversioned projection identity,
    // not a "latest" placeholder.
    version: ?reg.SemanticVersion,
    payload: []u8, // canonical JSON bytes; caller owns
};

pub fn deinitFrame(alloc: std.mem.Allocator, frame: *Frame) void {
    alloc.free(frame.projection_id);
    alloc.free(frame.payload);
    frame.* = Frame{
        .projection_id = &.{},
        .version = frame.version,
        .payload = &.{},
    };
}

fn ensureRegistered(id: reg.ProjectionId) FeedError!void {
    if (id.version == null) {
        if (reg.registry.nameHasMultiple(id.name)) return error.UnknownVersion;
        if (reg.registry.exists(id)) return;
        if (reg.registry.nameExists(id.name)) return error.UnknownVersion;
        return error.UnknownProjectionId;
    }

    if (reg.registry.exists(id)) return;
    if (reg.registry.nameExists(id.name)) return error.UnknownVersion;
    return error.UnknownProjectionId;
}

fn serializeEventKindsCanonical(alloc: std.mem.Allocator, kinds: []const proj.EventKind) ![]u8 {
    var buf = std.ArrayList(u8).init(alloc);
    errdefer buf.deinit();

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

    return buf.toOwnedSlice();
}

fn projectToFrame(alloc: std.mem.Allocator, id: reg.ProjectionId, events: []const ev.Event) FeedError!Frame {
    try ensureRegistered(id);

    if (!std.mem.eql(u8, id.name, "event.kind")) return error.UnsupportedProjection;

    const name_copy = try alloc.dupe(u8, id.name);
    errdefer alloc.free(name_copy);

    const kinds = try proj.projectEventKinds(alloc, events);
    defer alloc.free(kinds);

    const payload = try serializeEventKindsCanonical(alloc, kinds);
    return .{
        .projection_id = name_copy,
        .version = id.version,
        .payload = payload,
    };
}

pub fn buildFrame(alloc: std.mem.Allocator, id: reg.ProjectionId, events: []const ev.Event) FeedError!Frame {
    return projectToFrame(alloc, id, events);
}

pub fn buildFrames(alloc: std.mem.Allocator, ids: []const reg.ProjectionId, events: []const ev.Event) FeedError![]Frame {
    var list = std.ArrayList(Frame).init(alloc);
    errdefer {
        for (list.items) |*f| deinitFrame(alloc, f);
        list.deinit();
    }

    for (ids) |id| {
        const frame = try projectToFrame(alloc, id, events);
        try list.append(frame);
    }

    return list.toOwnedSlice();
}

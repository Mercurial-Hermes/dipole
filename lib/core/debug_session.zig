/// DebugSession
///
/// See docs/architecture/debug_session.md
///
/// Truth is an immutable, ordered log of events.
/// DebugSession is just the container + rules around that log.
const std = @import("std");
const EventMod = @import("event");
pub const Event = EventMod.Event;
pub const SnapshotKind = EventMod.SnapshotKind;

pub const DebugSession = struct {
    allocator: std.mem.Allocator,
    events: std.ArrayListUnmanaged(Event),

    pub fn init(allocator: std.mem.Allocator) DebugSession {
        return DebugSession{
            .allocator = allocator,
            .events = .{},
        };
    }

    pub fn initFromEvents(allocator: std.mem.Allocator, events: []const Event) !DebugSession {
        var session = DebugSession.init(allocator);
        errdefer session.deinit();
        for (events) |e| {
            var payload_copy: []const u8 = &.{};
            var owned = false;
            if (e.payload.len > 0) {
                payload_copy = try allocator.dupe(u8, e.payload);
                owned = true;
            }
            var snapshot_copy: ?EventMod.SnapshotPayload = null;
            if (e.snapshot) |snap| {
                var snap_payload: []const u8 = &.{};
                var snap_owned = false;
                if (snap.payload.len > 0) {
                    snap_payload = try allocator.dupe(u8, snap.payload);
                    snap_owned = true;
                }
                snapshot_copy = EventMod.SnapshotPayload{
                    .snapshot_kind = snap.snapshot_kind,
                    .source_id = snap.source_id,
                    .captured_at_event_seq = snap.captured_at_event_seq,
                    .payload = snap_payload,
                    .payload_owned = snap_owned,
                };
            }
            try session.events.append(allocator, .{
                .event_id = e.event_id,
                .category = e.category,
                .timestamp = e.timestamp,
                .payload = payload_copy,
                .payload_owned = owned,
                .snapshot = snapshot_copy,
            });
        }
        return session;
    }

    pub fn deinit(self: *DebugSession) void {
        for (self.events.items) |e| {
            if (e.payload_owned and e.payload.len > 0) {
                self.allocator.free(e.payload);
            }
            if (e.snapshot) |snap| {
                if (snap.payload_owned and snap.payload.len > 0) {
                    self.allocator.free(snap.payload);
                }
            }
        }
        self.events.deinit(self.allocator);
    }

    pub fn append(self: *DebugSession, category: EventMod.Category) !void {
        // This is the immutable event identifier assigned at append time.
        // Ordering comes from slice position; event_id labels the event for identity/replay.
        // If a timestamp exists, it must come from:
        //      an execution source
        //      a backend
        //      a replayed dataset
        //      or a later derivation step
        const event_id = self.events.items.len;
        try self.events.append(self.allocator, .{
            .event_id = event_id,
            .category = category,
            .timestamp = null,
        });
    }

    pub fn appendWithPayload(
        self: *DebugSession,
        category: EventMod.Category,
        payload: []const u8,
    ) !void {
        const event_id = self.events.items.len;
        try self.events.append(self.allocator, .{
            .event_id = event_id,
            .category = category,
            .timestamp = null,
            .payload = payload,
            .payload_owned = true,
        });
    }

    pub fn appendSnapshot(
        self: *DebugSession,
        snapshot_kind: SnapshotKind,
        source_id: u32,
        captured_at_event_seq: u64,
        payload: []const u8,
    ) !void {
        const event_id = self.events.items.len;
        const payload_copy = if (payload.len > 0) try self.allocator.dupe(u8, payload) else &.{};
        try self.events.append(self.allocator, .{
            .event_id = event_id,
            .category = .snapshot,
            .timestamp = null,
            .snapshot = EventMod.SnapshotPayload{
                .snapshot_kind = snapshot_kind,
                .source_id = source_id,
                .captured_at_event_seq = captured_at_event_seq,
                .payload = payload_copy,
                .payload_owned = payload.len > 0,
            },
        });
    }

    pub fn nextEventSeq(self: *const DebugSession) u64 {
        return self.events.items.len;
    }

    /// Immutable view of the event log.
    pub fn eventsView(self: *const DebugSession) []const Event {
        return self.events.items;
    }
};

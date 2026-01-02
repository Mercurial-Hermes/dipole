/// DebugSession
///
/// See docs/architecture/debug_session.md
///
/// Truth is an immutable, ordered log of events.
/// DebugSession is just the container + rules around that log.
const std = @import("std");
const EventMod = @import("event");
pub const Event = EventMod.Event;

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
            try session.events.append(allocator, .{
                .event_id = e.event_id,
                .category = e.category,
                .timestamp = e.timestamp,
                .payload = payload_copy,
                .payload_owned = owned,
            });
        }
        return session;
    }

    pub fn deinit(self: *DebugSession) void {
        for (self.events.items) |e| {
            if (e.payload_owned and e.payload.len > 0) {
                self.allocator.free(e.payload);
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

    /// Immutable view of the event log.
    pub fn eventsView(self: *const DebugSession) []const Event {
        return self.events.items;
    }
};

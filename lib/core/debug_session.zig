// Truth is an immutable, ordered log of events.
// DebugSession is just the container + rules around that log.

const std = @import("std");
const EventMod = @import("event.zig");
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
        try session.events.appendSlice(allocator, events);
        return session;
    }

    pub fn deinit(self: *DebugSession) void {
        self.events.deinit(self.allocator);
    }

    pub fn append(self: *DebugSession, category: EventMod.Category) !void {
        // this is the immutable sequence number to determine 'kernel' truth of order
        // events can have the same timestamp, but must have a unique sequence number
        // in this append: An event of category X was observed, and it occupies position N in the immutable log.
        // If a timestamp exists, it must come from:
        //      an execution source
        //      a backend
        //      a replayed dataset
        //      or a later derivation step
        const seq = self.events.items.len;
        try self.events.append(self.allocator, .{
            .seq = seq,
            .category = category,
            .timestamp = null,
        });
    }

    /// Immutable view of the event log.
    pub fn eventsView(self: *const DebugSession) []const Event {
        return self.events.items;
    }
};

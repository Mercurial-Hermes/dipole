/// Controller.zig
///
/// See docs/architecture/dipole-minimal-type-graph.md
/// See docs/architecture/dipole-module-boundary.md
/// See docs/architecture/execution-source.md
/// See docs/architecture/interaction-flow.md
///
/// A Controller brokers the interaction with the debugger
/// It talks to the driver and admits observations as Events
/// It enforces order and sequence of events
///
const std = @import("std");
const EventMod = @import("event.zig");
const DebugSessionMod = @import("debug_session.zig");
const DriverMod = @import("driver");
pub const Event = EventMod.Event;
pub const Category = EventMod.Category;
pub const DebugSession = DebugSessionMod.DebugSession;
pub const Driver = DriverMod.Driver;
pub const DriverObservation = DriverMod.DriverObservation;

pub const Controller = struct {
    /// Reserved for future event payload allocation / async ingestion
    allocator: std.mem.Allocator,
    session: *DebugSession,
    driver: Driver,

    pub fn init(
        allocator: std.mem.Allocator,
        session: *DebugSession,
        driver: Driver,
    ) Controller {
        return .{
            .allocator = allocator,
            .session = session,
            .driver = driver,
        };
    }

    pub fn issueRawCommand(self: *Controller, line: []const u8) !void {
        try self.driver.send(self.driver.ctx, line);

        while (self.driver.poll(self.driver.ctx)) |obs| {
            // Transport-level observation → coarse, non-semantic category
            const category: Category = switch (obs) {
                .tx => .command,
                .rx => .backend,
                .prompt => .backend,
            };

            try self.session.append(category);
        }
    }
};

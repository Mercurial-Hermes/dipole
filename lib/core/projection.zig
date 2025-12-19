/// Projection
///
/// See docs/architecture/derived_state.md
/// See docs/architecture/semantic-derivation.md
///
const std = @import("std");
const EventMod = @import("event.zig");
pub const Event = EventMod.Event;
pub const Category = EventMod.Category;

/// Returns the total number of events in the log.
///
/// This is a trivial projection used to establish the projection boundary.
/// Projections are pure, non-authoritative, and rebuildable.
pub fn eventCount(events: []const Event) usize {
    return events.len;
}

/// Returns an AutoHashMap containing the number of events in the log by category.
///
pub fn eventCountsByCategory(
    alloc: std.mem.Allocator,
    events: []const Event,
) !std.AutoHashMap(Category, usize) {
    var counts_by_category = std.AutoHashMap(Category, usize).init(alloc);
    errdefer counts_by_category.deinit();

    for (events) |ev| {
        const gop = try counts_by_category.getOrPut(ev.category);
        if (gop.found_existing) {
            gop.value_ptr.* += 1;
        } else {
            gop.value_ptr.* = 1;
        }
    }
    return counts_by_category; // caller owns and deinit’s
}

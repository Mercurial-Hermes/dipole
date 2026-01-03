const std = @import("std");
const ev = @import("event");

test "event defaults are stable and non-owning" {
    const e = ev.Event{
        .category = .session,
        .event_id = 0,
    };

    try std.testing.expectEqual(@as(usize, 0), e.payload.len);
    try std.testing.expect(!e.payload_owned);
    try std.testing.expect(e.snapshot == null);
}

test "snapshot payload default ownership is false" {
    const snap = ev.SnapshotPayload{
        .snapshot_kind = .registers,
        .source_id = 1,
        .captured_at_event_seq = 0,
        .payload = &.{},
    };

    try std.testing.expectEqual(@as(usize, 0), snap.payload.len);
    try std.testing.expect(!snap.payload_owned);
}

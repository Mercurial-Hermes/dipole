const std = @import("std");

pub const TraceSnapshot = struct {
    pc: usize,
    timestamp_ns: i128,
};

pub const TraceStep = struct {
    before: TraceSnapshot,
    after: TraceSnapshot,

    pub fn pcDeltaBytes(self: TraceStep) isize {
        const b = @as(isize, @intCast(self.before.pc));
        const a = @as(isize, @intCast(self.after.pc));
        return a - b;
    }
};

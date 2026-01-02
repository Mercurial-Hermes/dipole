const std = @import("std");
const posix = std.posix;

pub const Envelope = struct {
    source_id: u32,
    payload: []u8,
};

pub fn writeEnvelope(fd: posix.fd_t, source_id: u32, payload: []const u8) !void {
    var header: [8]u8 = undefined;
    std.mem.writeInt(u32, header[0..4], source_id, .little);
    std.mem.writeInt(u32, header[4..8], @as(u32, @intCast(payload.len)), .little);
    try writeAll(fd, &header);
    if (payload.len > 0) {
        try writeAll(fd, payload);
    }
}

pub fn readEnvelope(allocator: std.mem.Allocator, fd: posix.fd_t) !?Envelope {
    var header: [8]u8 = undefined;
    const header_ok = try readExact(fd, &header);
    if (!header_ok) return null;

    const source_id = std.mem.readInt(u32, header[0..4], .little);
    const len = std.mem.readInt(u32, header[4..8], .little);
    if (len == 0) {
        return Envelope{ .source_id = source_id, .payload = &.{} };
    }

    const payload = try allocator.alloc(u8, len);
    errdefer allocator.free(payload);
    const payload_ok = try readExact(fd, payload);
    if (!payload_ok) return error.EndOfStream;
    return Envelope{ .source_id = source_id, .payload = payload };
}

pub fn readExact(fd: posix.fd_t, buf: []u8) !bool {
    var off: usize = 0;
    while (off < buf.len) {
        const n = posix.read(fd, buf[off..]) catch |err| switch (err) {
            error.WouldBlock => 0,
            else => return err,
        };
        if (n == 0) return false;
        off += n;
    }
    return true;
}

pub fn writeAll(fd: posix.fd_t, buf: []const u8) !void {
    var off: usize = 0;
    while (off < buf.len) {
        const n = try posix.write(fd, buf[off..]);
        if (n == 0) return error.WriteFailed;
        off += n;
    }
}

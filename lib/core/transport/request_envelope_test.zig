const std = @import("std");
const request_envelope = @import("request_envelope");

fn readAllFromFd(fd: std.posix.fd_t, buf: []u8) !usize {
    var off: usize = 0;
    while (off < buf.len) {
        const n = std.posix.read(fd, buf[off..]) catch |err| switch (err) {
            error.WouldBlock => 0,
            else => return err,
        };
        if (n == 0) break;
        off += n;
    }
    return off;
}

test "request envelope encodes source_id and length correctly" {
    var fds = try std.posix.pipe();
    defer {
        if (fds[0] >= 0) _ = std.posix.close(fds[0]);
        if (fds[1] >= 0) _ = std.posix.close(fds[1]);
    }

    const payload = "help\n";
    try request_envelope.writeEnvelope(fds[1], 0x11223344, payload);
    _ = std.posix.close(fds[1]);
    fds[1] = -1;

    var buf: [13]u8 = undefined;
    const n = try readAllFromFd(fds[0], &buf);
    try std.testing.expectEqual(@as(usize, 13), n);

    try std.testing.expectEqual(@as(u32, 0x11223344), std.mem.readInt(u32, buf[0..4], .little));
    try std.testing.expectEqual(@as(u32, payload.len), std.mem.readInt(u32, buf[4..8], .little));
    try std.testing.expectEqualStrings(payload, buf[8..13]);
}

test "request envelope supports zero-length payload" {
    var fds = try std.posix.pipe();
    defer {
        if (fds[0] >= 0) _ = std.posix.close(fds[0]);
        if (fds[1] >= 0) _ = std.posix.close(fds[1]);
    }

    try request_envelope.writeEnvelope(fds[1], 7, "");
    _ = std.posix.close(fds[1]);
    fds[1] = -1;

    const env = (try request_envelope.readEnvelope(std.testing.allocator, fds[0])) orelse {
        return error.ExpectedEnvelope;
    };
    defer std.testing.allocator.free(env.payload);
    try std.testing.expectEqual(@as(u32, 7), env.source_id);
    try std.testing.expectEqual(@as(usize, 0), env.payload.len);
}

test "request envelope returns null on clean EndOfStream" {
    var fds = try std.posix.pipe();
    defer {
        if (fds[0] >= 0) _ = std.posix.close(fds[0]);
        if (fds[1] >= 0) _ = std.posix.close(fds[1]);
    }

    _ = std.posix.close(fds[1]);
    fds[1] = -1;
    const env = try request_envelope.readEnvelope(std.testing.allocator, fds[0]);
    try std.testing.expect(env == null);
}

test "request envelope returns null on partial header" {
    var fds = try std.posix.pipe();
    defer {
        if (fds[0] >= 0) _ = std.posix.close(fds[0]);
        if (fds[1] >= 0) _ = std.posix.close(fds[1]);
    }

    const partial_header = [_]u8{ 1, 2, 3, 4 };
    _ = try std.posix.write(fds[1], &partial_header);
    _ = std.posix.close(fds[1]);
    fds[1] = -1;

    const env = try request_envelope.readEnvelope(std.testing.allocator, fds[0]);
    try std.testing.expect(env == null);
}

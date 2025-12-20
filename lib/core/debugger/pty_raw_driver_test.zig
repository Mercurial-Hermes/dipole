const std = @import("std");
const pty = @import("pty_raw_driver.zig");
const driver = @import("driver");

test "pty raw driver: poll returns null when no data available" {
    const alloc = std.testing.allocator;

    // Create a pipe and make the read end non-blocking.
    const fds = try std.posix.pipe();
    const rfd = fds[0];
    const wfd = fds[1];
    defer std.posix.close(wfd);

    var flags = try std.posix.fcntl(rfd, std.posix.F.GETFL, 0);
    flags |= 1 << @bitOffsetOf(std.posix.O, "NONBLOCK");
    _ = try std.posix.fcntl(rfd, std.posix.F.SETFL, flags);

    var drv_impl = pty.PtyRawDriver.init(alloc, rfd);
    defer drv_impl.deinit();

    const d = drv_impl.asDriver();
    const obs = d.poll(d.ctx);
    try std.testing.expectEqual(@as(?driver.DriverObservation, null), obs);
}

test "pty raw driver: poll emits exactly what was written (no aggregation)" {
    const alloc = std.testing.allocator;

    const fds = try std.posix.pipe();
    const rfd = fds[0];
    const wfd = fds[1];
    defer std.posix.close(wfd);

    // Darwin uses packed bitfields for O_* flags; must set via bit offset.
    var flags = try std.posix.fcntl(rfd, std.posix.F.GETFL, 0);
    flags |= 1 << @bitOffsetOf(std.posix.O, "NONBLOCK");
    _ = try std.posix.fcntl(rfd, std.posix.F.SETFL, flags);

    var drv_impl = pty.PtyRawDriver.init(alloc, rfd);
    defer drv_impl.deinit();

    const d = drv_impl.asDriver();

    // Write first fragment and poll once.
    _ = try std.posix.write(wfd, "abc");
    const obs1 = d.poll(d.ctx) orelse unreachable;
    defer alloc.free(obs1.rx);
    try std.testing.expectEqualStrings("abc", obs1.rx);

    // Write second fragment and poll again.
    _ = try std.posix.write(wfd, "def");
    const obs2 = d.poll(d.ctx) orelse unreachable;
    defer alloc.free(obs2.rx);
    try std.testing.expectEqualStrings("def", obs2.rx);
}

test "pty raw driver: send writes bytes verbatim" {
    const alloc = std.testing.allocator;

    const fds = try std.posix.pipe();
    const rfd = fds[0];
    const wfd = fds[1];
    defer std.posix.close(rfd);

    var drv_impl = pty.PtyRawDriver.init(alloc, wfd);
    defer drv_impl.deinit();

    const d = drv_impl.asDriver();

    try d.send(d.ctx, "xyz");

    var buf: [3]u8 = undefined;
    const n = try std.posix.read(rfd, &buf);
    try std.testing.expectEqual(@as(usize, 3), n);
    try std.testing.expectEqualStrings("xyz", buf[0..n]);
}

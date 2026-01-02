const std = @import("std");
const fd_utils = @import("fd_utils");

test "setCloexec toggles FD_CLOEXEC" {
    const fds = try std.posix.pipe();
    defer {
        if (fds[0] >= 0) _ = std.posix.close(fds[0]);
        if (fds[1] >= 0) _ = std.posix.close(fds[1]);
    }

    try fd_utils.setCloexec(fds[0], false);
    var flags = try std.posix.fcntl(fds[0], std.posix.F.GETFD, 0);
    try std.testing.expect((flags & std.posix.FD_CLOEXEC) == 0);

    try fd_utils.setCloexec(fds[0], true);
    flags = try std.posix.fcntl(fds[0], std.posix.F.GETFD, 0);
    try std.testing.expect((flags & std.posix.FD_CLOEXEC) != 0);
}

test "setNonblocking toggles O_NONBLOCK" {
    const fds = try std.posix.pipe();
    defer {
        if (fds[0] >= 0) _ = std.posix.close(fds[0]);
        if (fds[1] >= 0) _ = std.posix.close(fds[1]);
    }

    try fd_utils.setNonblocking(fds[0], false);
    var flags = try std.posix.fcntl(fds[0], std.posix.F.GETFL, 0);
    try std.testing.expect((flags & (1 << @bitOffsetOf(std.posix.O, "NONBLOCK"))) == 0);

    try fd_utils.setNonblocking(fds[0], true);
    flags = try std.posix.fcntl(fds[0], std.posix.F.GETFL, 0);
    try std.testing.expect((flags & (1 << @bitOffsetOf(std.posix.O, "NONBLOCK"))) != 0);
}

test "closeFd is idempotent" {
    const fds = try std.posix.pipe();
    var fd = fds[0];
    _ = std.posix.close(fds[1]);
    fd_utils.closeFd(&fd);
    fd_utils.closeFd(&fd);
    try std.testing.expectEqual(@as(std.posix.fd_t, -1), fd);
}

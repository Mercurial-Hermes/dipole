const std = @import("std");
const posix = std.posix;

pub fn createPipe() ![2]posix.fd_t {
    return try posix.pipe();
}

pub fn closeFd(fd: *posix.fd_t) void {
    if (fd.* >= 0) {
        _ = posix.close(fd.*);
        fd.* = -1;
    }
}

pub fn setCloexec(fd: posix.fd_t, enabled: bool) !void {
    var flags = try posix.fcntl(fd, posix.F.GETFD, 0);
    const cloexec_mask: usize = @as(usize, posix.FD_CLOEXEC);
    if (enabled) {
        flags |= cloexec_mask;
    } else {
        flags &= ~cloexec_mask;
    }
    _ = try posix.fcntl(fd, posix.F.SETFD, flags);
}

pub fn setNonblocking(fd: posix.fd_t, enabled: bool) !void {
    var flags = try posix.fcntl(fd, posix.F.GETFL, 0);
    const nonblock_mask: usize = 1 << @bitOffsetOf(posix.O, "NONBLOCK");
    if (enabled) {
        flags |= nonblock_mask;
    } else {
        flags &= ~nonblock_mask;
    }
    _ = try posix.fcntl(fd, posix.F.SETFL, flags);
}

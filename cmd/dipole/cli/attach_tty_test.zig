const std = @import("std");
const attach_session = @import("attach_session");

test "attach enters interactive mode when stdin is TTY and no session commands" {
    try std.testing.expect(attach_session.shouldReadStdin(false, true));
    try std.testing.expect(!attach_session.shouldReadStdin(true, true));
    try std.testing.expect(!attach_session.shouldReadStdin(false, false));
}

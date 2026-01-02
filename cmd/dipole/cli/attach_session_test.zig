const std = @import("std");
const attach_session = @import("attach_session");

test "attach session parses command tokens" {
    try std.testing.expectEqual(attach_session.SessionCommand.interrupt, attach_session.parseSessionCommand("interrupt").?);
    try std.testing.expectEqual(attach_session.SessionCommand.@"continue", attach_session.parseSessionCommand("continue").?);
    try std.testing.expectEqual(attach_session.SessionCommand.detach, attach_session.parseSessionCommand("detach").?);
}

test "attach session ignores unknown command tokens" {
    try std.testing.expect(attach_session.parseSessionCommand("step") == null);
    try std.testing.expect(attach_session.parseSessionCommand("") == null);
}

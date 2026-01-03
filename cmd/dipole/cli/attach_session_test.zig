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

test "attach session parses session fact flags" {
    try std.testing.expectEqual(attach_session.FactCategory.context, attach_session.parseFactFlag("--context").?);
    try std.testing.expectEqual(attach_session.FactCategory.provenance, attach_session.parseFactFlag("--provenance").?);
    try std.testing.expect(attach_session.parseFactFlag("--tmux") == null);
}

test "attach session collects facts in CLI order" {
    const alloc = std.testing.allocator;
    var commands = std.ArrayList([]const u8).init(alloc);
    defer commands.deinit();
    var facts = std.ArrayList(attach_session.SessionFact).init(alloc);
    defer facts.deinit();

    const tokens = [_][]const u8{
        "--context", "arm64",
        "interrupt",
        "--provenance", "lldb",
        "--context", "little-endian",
    };

    const use_tmux = try attach_session.parseAttachTokens(alloc, &tokens, &commands, &facts);
    try std.testing.expect(!use_tmux);
    try std.testing.expectEqual(@as(usize, 1), commands.items.len);
    try std.testing.expectEqualStrings("process interrupt\n", commands.items[0]);
    try std.testing.expectEqual(@as(usize, 3), facts.items.len);
    try std.testing.expectEqual(attach_session.FactCategory.context, facts.items[0].category);
    try std.testing.expectEqualStrings("arm64", facts.items[0].payload);
    try std.testing.expectEqual(attach_session.FactCategory.provenance, facts.items[1].category);
    try std.testing.expectEqualStrings("lldb", facts.items[1].payload);
    try std.testing.expectEqual(attach_session.FactCategory.context, facts.items[2].category);
    try std.testing.expectEqualStrings("little-endian", facts.items[2].payload);
}

test "attach session allows empty fact list" {
    const alloc = std.testing.allocator;
    var commands = std.ArrayList([]const u8).init(alloc);
    defer commands.deinit();
    var facts = std.ArrayList(attach_session.SessionFact).init(alloc);
    defer facts.deinit();

    const tokens = [_][]const u8{ "interrupt" };
    _ = try attach_session.parseAttachTokens(alloc, &tokens, &commands, &facts);
    try std.testing.expectEqual(@as(usize, 1), commands.items.len);
    try std.testing.expectEqual(@as(usize, 0), facts.items.len);
}

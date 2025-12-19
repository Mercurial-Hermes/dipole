// build_config.zig

pub const ModuleSpec = struct {
    name: []const u8, // how you import it: @import("name")
    root: []const u8, // path to the module root file
};

pub const modules = [_]ModuleSpec{
    .{ .name = "core", .root = "lib/core/debug_session.zig" },
    .{ .name = "core", .root = "lib/core/event.zig" },
    // add more as you grow:
    // .{ .name = "controller", .root = "lib/core/controller/Controller.zig" },
};

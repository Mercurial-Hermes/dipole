const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const test_step = b.step("test", "Run all tests");
    const proj_step = b.step("test-projection", "Run semantic projection tests");

    // Change this to wherever you keep tests.
    addTestsUnder(b, test_step, "lib", target, optimize);

    // Dedicated projection tests (semantic layer only)
    addSemanticTests(b, proj_step, "lib/core/semantic", target, optimize);
}

fn addTestsUnder(
    b: *std.Build,
    test_step: *std.Build.Step,
    root_rel: []const u8,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const root = b.path(root_rel);

    var dir = std.fs.openDirAbsolute(root.getPath(b), .{ .iterate = true }) catch |err| {
        std.debug.panic("failed to open '{s}': {s}", .{ root_rel, @errorName(err) });
    };
    defer dir.close();

    var it = dir.walk(a) catch |err| {
        std.debug.panic("failed to walk '{s}': {s}", .{ root_rel, @errorName(err) });
    };
    defer it.deinit();

    const driver_mod = b.addModule("driver", .{
        .root_source_file = b.path("lib/core/driver.zig"),
    });
    const debug_session_mod = b.addModule("debug_session", .{
        .root_source_file = b.path("lib/core/debug_session.zig"),
    });

    while (it.next() catch |err| {
        std.debug.panic("walk error in '{s}': {s}", .{ root_rel, @errorName(err) });
    }) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.path, "_test.zig")) continue;

        const rel_path = std.fs.path.join(a, &.{ root_rel, entry.path }) catch unreachable;

        const t = b.addTest(.{
            .root_source_file = b.path(rel_path),
            .target = target,
            .optimize = optimize,
        });
        t.root_module.addImport("driver", driver_mod);
        t.root_module.addImport("debug_session", debug_session_mod);

        const run = b.addRunArtifact(t);
        test_step.dependOn(&run.step);
    }
}

fn addSemanticTests(
    b: *std.Build,
    step: *std.Build.Step,
    root_rel: []const u8,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const debug_session_mod = b.addModule("debug_session", .{
        .root_source_file = b.path("lib/core/debug_session.zig"),
    });
    const driver_mod = b.addModule("driver", .{
        .root_source_file = b.path("lib/core/driver.zig"),
    });

    const root = b.path(root_rel);
    var dir = std.fs.openDirAbsolute(root.getPath(b), .{ .iterate = true }) catch |err| {
        std.debug.panic("failed to open '{s}': {s}", .{ root_rel, @errorName(err) });
    };
    defer dir.close();

    var it = dir.walk(a) catch |err| {
        std.debug.panic("failed to walk '{s}': {s}", .{ root_rel, @errorName(err) });
    };
    defer it.deinit();

    while (it.next() catch |err| {
        std.debug.panic("walk error in '{s}': {s}", .{ root_rel, @errorName(err) });
    }) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.path, "_test.zig")) continue;

        const rel_path = std.fs.path.join(a, &.{ root_rel, entry.path }) catch unreachable;

        const t = b.addTest(.{
            .root_source_file = b.path(rel_path),
            .target = target,
            .optimize = optimize,
        });
        t.root_module.addImport("debug_session", debug_session_mod);
        t.root_module.addImport("driver", driver_mod);

        const run = b.addRunArtifact(t);
        step.dependOn(&run.step);
    }
}

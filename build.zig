const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const test_step = b.step("test", "Run all tests");
    const proj_step = b.step("test-projection", "Run semantic projection tests");
    const cli_step = b.step("test-cli", "Run CLI tests");

    // Shared modules for CLI and tests.
    const event_kind_mod = b.addModule("event_kind", .{
        .root_source_file = b.path("lib/core/semantic/event_kind.zig"),
    });
    const semantic_registry_mod = b.addModule("semantic_registry", .{
        .root_source_file = b.path("lib/core/semantic/registry.zig"),
        .imports = &.{
            .{ .name = "event_kind", .module = event_kind_mod },
        },
    });
    const event_mod = b.addModule("event", .{
        .root_source_file = b.path("lib/core/event.zig"),
    });
    const semantic_list_mod = b.addModule("semantic_list", .{
        .root_source_file = b.path("cmd/dipole/cli/semantic_list.zig"),
        .imports = &.{
            .{ .name = "semantic_registry", .module = semantic_registry_mod },
        },
    });
    const semantic_show_mod = b.addModule("semantic_show", .{
        .root_source_file = b.path("cmd/dipole/cli/semantic_show.zig"),
        .imports = &.{
            .{ .name = "semantic_registry", .module = semantic_registry_mod },
        },
    });
    const projection_mod = b.addModule("projection", .{
        .root_source_file = b.path("lib/core/semantic/projection.zig"),
        .imports = &.{
            .{ .name = "event", .module = event_mod },
            .{ .name = "event_kind", .module = event_kind_mod },
        },
    });
    const semantic_eval_mod = b.addModule("semantic_eval", .{
        .root_source_file = b.path("cmd/dipole/cli/semantic_eval.zig"),
        .imports = &.{
            .{ .name = "semantic_registry", .module = semantic_registry_mod },
            .{ .name = "projection", .module = projection_mod },
            .{ .name = "event", .module = event_mod },
            .{ .name = "event_kind", .module = event_kind_mod },
        },
    });

    const dipole = b.addExecutable(.{
        .name = "dipole",
        .root_source_file = b.path("cmd/dipole/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    dipole.root_module.addImport("semantic_list", semantic_list_mod);
    dipole.root_module.addImport("semantic_show", semantic_show_mod);
    dipole.root_module.addImport("semantic_registry", semantic_registry_mod);
    dipole.root_module.addImport("semantic_eval", semantic_eval_mod);
    dipole.root_module.addImport("projection", projection_mod);
    dipole.root_module.addImport("event", event_mod);
    b.installArtifact(dipole);

    addCliTests(
        b,
        cli_step,
        test_step,
        "cmd/dipole/cli",
        target,
        optimize,
        .{
            .semantic_list = semantic_list_mod,
            .semantic_show = semantic_show_mod,
            .semantic_eval = semantic_eval_mod,
            .semantic_registry = semantic_registry_mod,
            .projection = projection_mod,
            .event = event_mod,
            .event_kind = event_kind_mod,
        },
    );

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

    const event_mod = b.addModule("event", .{
        .root_source_file = b.path("lib/core/event.zig"),
    });
    const driver_mod = b.addModule("driver", .{
        .root_source_file = b.path("lib/core/driver.zig"),
    });
    const debug_session_mod = b.addModule("debug_session", .{
        .root_source_file = b.path("lib/core/debug_session.zig"),
        .imports = &.{
            .{ .name = "event", .module = event_mod },
        },
    });
    const event_kind_mod = b.addModule("event_kind", .{
        .root_source_file = b.path("lib/core/semantic/event_kind.zig"),
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
        t.root_module.addImport("event", event_mod);
        t.root_module.addImport("event_kind", event_kind_mod);

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

    const event_mod = b.addModule("event", .{
        .root_source_file = b.path("lib/core/event.zig"),
    });
    const debug_session_mod = b.addModule("debug_session", .{
        .root_source_file = b.path("lib/core/debug_session.zig"),
        .imports = &.{
            .{ .name = "event", .module = event_mod },
        },
    });
    const driver_mod = b.addModule("driver", .{
        .root_source_file = b.path("lib/core/driver.zig"),
    });
    const event_kind_mod = b.addModule("event_kind", .{
        .root_source_file = b.path("lib/core/semantic/event_kind.zig"),
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
        t.root_module.addImport("event", event_mod);
        t.root_module.addImport("event_kind", event_kind_mod);

        const run = b.addRunArtifact(t);
        step.dependOn(&run.step);
    }
}

fn addCliTests(
    b: *std.Build,
    cli_step: *std.Build.Step,
    test_step: *std.Build.Step,
    root_rel: []const u8,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    mods: struct {
        semantic_list: *std.Build.Module,
        semantic_show: *std.Build.Module,
        semantic_eval: *std.Build.Module,
        semantic_registry: *std.Build.Module,
        projection: *std.Build.Module,
        event: *std.Build.Module,
        event_kind: *std.Build.Module,
    },
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
        t.root_module.addImport("semantic_list", mods.semantic_list);
        t.root_module.addImport("semantic_show", mods.semantic_show);
        t.root_module.addImport("semantic_eval", mods.semantic_eval);
        t.root_module.addImport("semantic_registry", mods.semantic_registry);
        t.root_module.addImport("projection", mods.projection);
        t.root_module.addImport("event", mods.event);
        t.root_module.addImport("event_kind", mods.event_kind);

        const run = b.addRunArtifact(t);
        test_step.dependOn(&run.step);
        cli_step.dependOn(&run.step);
    }
}

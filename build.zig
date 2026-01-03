const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const test_step = b.step("test", "Run all tests");
    const proj_step = b.step("test-projection", "Run semantic projection tests");
    const control_step = b.step("test-control", "Run control tests");
    const cli_step = b.step("test-cli", "Run CLI tests");
    const learning_step = b.step("learning-targets", "Build learning target programs");

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
    const debug_session_mod = b.addModule("debug_session", .{
        .root_source_file = b.path("lib/core/debug_session.zig"),
        .imports = &.{
            .{ .name = "event", .module = event_mod },
        },
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
    const semantic_feed_mod = b.addModule("semantic_feed", .{
        .root_source_file = b.path("lib/core/semantic/feed.zig"),
        .imports = &.{
            .{ .name = "registry.zig", .module = semantic_registry_mod },
            .{ .name = "projection.zig", .module = projection_mod },
            .{ .name = "event", .module = event_mod },
        },
    });
    const ui_adapter_mod = b.addModule("ui_adapter", .{
        .root_source_file = b.path("lib/core/semantic/ui_adapter.zig"),
        .imports = &.{
            .{ .name = "registry.zig", .module = semantic_registry_mod },
        },
    });
    const semantic_render_mod = b.addModule("semantic_render", .{
        .root_source_file = b.path("cmd/dipole/cli/semantic_render.zig"),
        .imports = &.{
            .{ .name = "semantic_registry", .module = semantic_registry_mod },
            .{ .name = "semantic_feed", .module = semantic_feed_mod },
            .{ .name = "ui_adapter", .module = ui_adapter_mod },
            .{ .name = "event", .module = event_mod },
        },
    });
    const driver_mod = b.addModule("driver", .{
        .root_source_file = b.path("lib/core/driver.zig"),
    });
    const pty_mod = b.addModule("pty", .{
        .root_source_file = b.path("lib/core/debugger/pty.zig"),
    });
    const lldb_launcher_mod = b.addModule("lldb_launcher", .{
        .root_source_file = b.path("lib/core/debugger/lldb_launcher.zig"),
        .imports = &.{
            .{ .name = "pty", .module = pty_mod },
        },
    });
    const pty_raw_driver_mod = b.addModule("pty_raw_driver", .{
        .root_source_file = b.path("lib/core/debugger/pty_raw_driver.zig"),
        .imports = &.{
            .{ .name = "driver", .module = driver_mod },
        },
    });
    const request_envelope_mod = b.addModule("request_envelope", .{
        .root_source_file = b.path("lib/core/transport/request_envelope.zig"),
    });
    const fd_utils_mod = b.addModule("fd_utils", .{
        .root_source_file = b.path("lib/core/transport/fd_utils.zig"),
    });
    const controller_mod = b.addModule("controller", .{
        .root_source_file = b.path("lib/core/controller.zig"),
        .imports = &.{
            .{ .name = "event", .module = event_mod },
            .{ .name = "debug_session.zig", .module = debug_session_mod },
            .{ .name = "driver", .module = driver_mod },
            .{ .name = "request_envelope", .module = request_envelope_mod },
        },
    });
    const pane_runtime_mod = b.addModule("pane_runtime", .{
        .root_source_file = b.path("cmd/dipole/ui/pane_runtime.zig"),
        .imports = &.{
            .{ .name = "request_envelope", .module = request_envelope_mod },
        },
    });
    const tmux_session_mod = b.addModule("tmux_session", .{
        .root_source_file = b.path("cmd/dipole/ui/tmux_session.zig"),
    });
    const attach_session_impl_mod = b.addModule("attach_session_impl", .{
        .root_source_file = b.path("cmd/dipole/cli/attach_session_impl.zig"),
        .imports = &.{
            .{ .name = "controller", .module = controller_mod },
            .{ .name = "debug_session", .module = debug_session_mod },
            .{ .name = "lldb_launcher", .module = lldb_launcher_mod },
            .{ .name = "pty_raw_driver", .module = pty_raw_driver_mod },
            .{ .name = "request_envelope", .module = request_envelope_mod },
            .{ .name = "fd_utils", .module = fd_utils_mod },
            .{ .name = "pane_runtime", .module = pane_runtime_mod },
            .{ .name = "tmux_session", .module = tmux_session_mod },
            .{ .name = "projection", .module = projection_mod },
            .{ .name = "event", .module = event_mod },
        },
    });
    const attach_session_mod = b.addModule("attach_session", .{
        .root_source_file = b.path("cmd/dipole/cli/attach_session.zig"),
        .imports = &.{
            .{ .name = "attach_session_impl", .module = attach_session_impl_mod },
            .{ .name = "pane_runtime", .module = pane_runtime_mod },
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
    dipole.root_module.addImport("semantic_render", semantic_render_mod);
    dipole.root_module.addImport("semantic_feed", semantic_feed_mod);
    dipole.root_module.addImport("ui_adapter", ui_adapter_mod);
    dipole.root_module.addImport("projection", projection_mod);
    dipole.root_module.addImport("event", event_mod);
    dipole.root_module.addImport("debug_session", debug_session_mod);
    dipole.root_module.addImport("controller", controller_mod);
    dipole.root_module.addImport("attach_session", attach_session_mod);
    dipole.root_module.addImport("lldb_launcher", lldb_launcher_mod);
    dipole.root_module.addImport("pty_raw_driver", pty_raw_driver_mod);
    b.installArtifact(dipole);
    b.getInstallStep().dependOn(learning_step);

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
            .semantic_render = semantic_render_mod,
        .semantic_registry = semantic_registry_mod,
        .projection = projection_mod,
        .event = event_mod,
        .event_kind = event_kind_mod,
        .semantic_feed = semantic_feed_mod,
        .ui_adapter = ui_adapter_mod,
        .attach_session = attach_session_mod,
        .controller = controller_mod,
        .request_envelope = request_envelope_mod,
        .pane_runtime = pane_runtime_mod,
        .fd_utils = fd_utils_mod,
    },
    );

    addCliTests(
        b,
        cli_step,
        test_step,
        "cmd/dipole/ui",
        target,
        optimize,
        .{
            .semantic_list = semantic_list_mod,
            .semantic_show = semantic_show_mod,
            .semantic_eval = semantic_eval_mod,
            .semantic_render = semantic_render_mod,
        .semantic_registry = semantic_registry_mod,
        .projection = projection_mod,
        .event = event_mod,
        .event_kind = event_kind_mod,
        .semantic_feed = semantic_feed_mod,
        .ui_adapter = ui_adapter_mod,
        .attach_session = attach_session_mod,
        .controller = controller_mod,
        .request_envelope = request_envelope_mod,
        .pane_runtime = pane_runtime_mod,
        .fd_utils = fd_utils_mod,
    },
    );

    addCliTests(
        b,
        cli_step,
        test_step,
        "lib/core/transport",
        target,
        optimize,
        .{
            .semantic_list = semantic_list_mod,
            .semantic_show = semantic_show_mod,
            .semantic_eval = semantic_eval_mod,
            .semantic_render = semantic_render_mod,
        .semantic_registry = semantic_registry_mod,
        .projection = projection_mod,
        .event = event_mod,
        .event_kind = event_kind_mod,
        .semantic_feed = semantic_feed_mod,
        .ui_adapter = ui_adapter_mod,
        .attach_session = attach_session_mod,
        .controller = controller_mod,
        .request_envelope = request_envelope_mod,
        .pane_runtime = pane_runtime_mod,
        .fd_utils = fd_utils_mod,
    },
    );

    // Change this to wherever you keep tests.
    addTestsUnder(b, test_step, "lib", target, optimize);
    addControlTests(
        b,
        control_step,
        target,
        optimize,
    );
    test_step.dependOn(control_step);

    // Dedicated projection tests (semantic layer only)
    addSemanticTests(b, proj_step, "lib/core/semantic", target, optimize);
    addLearningTargets(b, learning_step, target, optimize);
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
    const request_envelope_mod = b.addModule("request_envelope", .{
        .root_source_file = b.path("lib/core/transport/request_envelope.zig"),
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
    const projection_mod = b.addModule("projection", .{
        .root_source_file = b.path("lib/core/semantic/projection.zig"),
        .imports = &.{
            .{ .name = "event", .module = event_mod },
            .{ .name = "event_kind", .module = event_kind_mod },
        },
    });
    const semantic_registry_mod = b.addModule("semantic_registry", .{
        .root_source_file = b.path("lib/core/semantic/registry.zig"),
        .imports = &.{
            .{ .name = "event_kind", .module = event_kind_mod },
        },
    });
    const semantic_feed_mod = b.addModule("semantic_feed", .{
        .root_source_file = b.path("lib/core/semantic/feed.zig"),
        .imports = &.{
            .{ .name = "registry.zig", .module = semantic_registry_mod },
            .{ .name = "projection.zig", .module = projection_mod },
            .{ .name = "event", .module = event_mod },
        },
    });
    const controller_mod = b.addModule("controller", .{
        .root_source_file = b.path("lib/core/controller.zig"),
        .imports = &.{
            .{ .name = "event", .module = event_mod },
            .{ .name = "debug_session.zig", .module = debug_session_mod },
            .{ .name = "driver", .module = driver_mod },
            .{ .name = "request_envelope", .module = request_envelope_mod },
        },
    });

    while (it.next() catch |err| {
        std.debug.panic("walk error in '{s}': {s}", .{ root_rel, @errorName(err) });
    }) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.path, "_test.zig")) continue;
        if (std.mem.startsWith(u8, entry.path, "core/control/")) continue;
        if (std.mem.startsWith(u8, entry.path, "core/transport/")) continue;

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
        t.root_module.addImport("projection", projection_mod);
        t.root_module.addImport("semantic_registry", semantic_registry_mod);
        t.root_module.addImport("semantic_feed", semantic_feed_mod);
        t.root_module.addImport("controller", controller_mod);

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

fn addControlTests(
    b: *std.Build,
    step: *std.Build.Step,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const event_mod = b.addModule("event", .{
        .root_source_file = b.path("lib/core/event.zig"),
    });
    const driver_mod = b.addModule("driver", .{
        .root_source_file = b.path("lib/core/driver.zig"),
    });
    const debug_session_mod = b.addModule("debug_session.zig", .{
        .root_source_file = b.path("lib/core/debug_session.zig"),
        .imports = &.{
            .{ .name = "event", .module = event_mod },
        },
    });
    const event_kind_mod = b.addModule("event_kind", .{
        .root_source_file = b.path("lib/core/semantic/event_kind.zig"),
    });
    const projection_mod = b.addModule("projection", .{
        .root_source_file = b.path("lib/core/semantic/projection.zig"),
        .imports = &.{
            .{ .name = "event", .module = event_mod },
            .{ .name = "event_kind", .module = event_kind_mod },
        },
    });
    const semantic_registry_mod = b.addModule("semantic_registry", .{
        .root_source_file = b.path("lib/core/semantic/registry.zig"),
        .imports = &.{
            .{ .name = "event_kind", .module = event_kind_mod },
        },
    });
    const semantic_feed_mod = b.addModule("semantic_feed", .{
        .root_source_file = b.path("lib/core/semantic/feed.zig"),
        .imports = &.{
            .{ .name = "registry.zig", .module = semantic_registry_mod },
            .{ .name = "projection.zig", .module = projection_mod },
            .{ .name = "event", .module = event_mod },
        },
    });
    const controller_mod = b.addModule("controller", .{
        .root_source_file = b.path("lib/core/controller.zig"),
        .imports = &.{
            .{ .name = "event", .module = event_mod },
            .{ .name = "debug_session.zig", .module = debug_session_mod },
            .{ .name = "driver", .module = driver_mod },
        },
    });

    const root_rel = "lib/core/control";
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
        t.root_module.addImport("driver", driver_mod);
        t.root_module.addImport("debug_session", debug_session_mod);
        t.root_module.addImport("event", event_mod);
        t.root_module.addImport("event_kind", event_kind_mod);
        t.root_module.addImport("projection", projection_mod);
        t.root_module.addImport("semantic_registry", semantic_registry_mod);
        t.root_module.addImport("semantic_feed", semantic_feed_mod);
        t.root_module.addImport("controller", controller_mod);

        const run = b.addRunArtifact(t);
        step.dependOn(&run.step);
    }
}

fn addLearningTargets(
    b: *std.Build,
    step: *std.Build.Step,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const root_rel = "learning_targets";
    const root = b.path(root_rel);

    var dir = std.fs.openDirAbsolute(root.getPath(b), .{ .iterate = true }) catch {
        // If the directory doesn't exist, nothing to build.
        return;
    };
    defer dir.close();

    var it = dir.iterate();
    while (it.next() catch |err| {
        std.debug.panic("walk error in '{s}': {s}", .{ root_rel, @errorName(err) });
    }) |entry| {
        if (entry.kind != .directory) continue;
        if (entry.name.len == 0 or entry.name[0] == '.') continue;

        const main_rel = std.fs.path.join(a, &.{ root_rel, entry.name, "main.c" }) catch unreachable;
        std.fs.cwd().access(main_rel, .{}) catch continue; // skip if no main.c

        const exe = b.addExecutable(.{
            .name = entry.name,
            .target = target,
            .optimize = optimize,
        });
        exe.addCSourceFile(.{
            .file = b.path(main_rel),
            .flags = &.{ "-std=c11" },
        });
        exe.linkLibC();
        b.installArtifact(exe);
        step.dependOn(&exe.step);
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
        semantic_render: *std.Build.Module,
        semantic_registry: *std.Build.Module,
        projection: *std.Build.Module,
        event: *std.Build.Module,
        event_kind: *std.Build.Module,
        semantic_feed: *std.Build.Module,
        ui_adapter: *std.Build.Module,
        attach_session: *std.Build.Module,
        controller: *std.Build.Module,
        request_envelope: *std.Build.Module,
        pane_runtime: *std.Build.Module,
        fd_utils: *std.Build.Module,
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
        t.root_module.addImport("semantic_render", mods.semantic_render);
        t.root_module.addImport("semantic_registry", mods.semantic_registry);
        t.root_module.addImport("semantic_feed", mods.semantic_feed);
        t.root_module.addImport("ui_adapter", mods.ui_adapter);
        t.root_module.addImport("projection", mods.projection);
        t.root_module.addImport("event", mods.event);
        t.root_module.addImport("event_kind", mods.event_kind);
        t.root_module.addImport("attach_session", mods.attach_session);
        t.root_module.addImport("controller", mods.controller);
        t.root_module.addImport("request_envelope", mods.request_envelope);
        t.root_module.addImport("pane_runtime", mods.pane_runtime);
        t.root_module.addImport("fd_utils", mods.fd_utils);

        const run = b.addRunArtifact(t);
        test_step.dependOn(&run.step);
        cli_step.dependOn(&run.step);
    }
}

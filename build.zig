const std = @import("std");

fn addSimpleProgram(
    b: *std.Build,
    name: []const u8,
    source: []const u8,
    is_c: bool,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) !*std.Build.Step {
    const exe = b.addExecutable(.{
        .name = name,
        .target = target,
        .optimize = optimize,
    });

    if (is_c) {
        exe.addCSourceFile(.{
            .file = b.path(source),
            .flags = &.{"-g"},
        });
        exe.linkLibC();
    } else {
        exe.root_module.root_source_file = b.path(source);
    }

    const install_exe = b.addInstallArtifact(exe, .{});

    const step = b.step(name, "Build simple program");
    step.dependOn(&install_exe.step);

    b.getInstallStep().dependOn(&install_exe.step);

    return step;
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const trace_mod = b.createModule(.{
        .root_source_file = b.path("lib/core/trace.zig"),
    });

    const args_mod = b.createModule(.{
        .root_source_file = b.path("lib/core/Args.zig"),
        .target = target,
        .optimize = optimize,
    });

    const ansi_mod = b.createModule(.{
        .root_source_file = b.path("lib/core/ansi.zig"),
        .target = target,
        .optimize = optimize,
    });

    const term_mod = b.createModule(.{
        .root_source_file = b.path("lib/core/term.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lldbdriver_mod = b.createModule(.{
        .root_source_file = b.path("lib/core/debugger/LLDBDriver.zig"),
        .target = target,
        .optimize = optimize,
    });

    const log_mod = b.createModule(.{
        .root_source_file = b.path("lib/core/Log.zig"),
        .target = target,
        .optimize = optimize,
    });

    lldbdriver_mod.addImport("log", log_mod);

    const tui_mod = b.createModule(.{
        .root_source_file = b.path("lib/ui/tui.zig"),
        .target = target,
        .optimize = optimize,
    });

    tui_mod.addImport("log", log_mod);
    tui_mod.addImport("term", term_mod);

    const tmux_mod = b.createModule(.{
        .root_source_file = b.path("lib/core/Tmux.zig"),
        .target = target,
        .optimize = optimize,
    });

    tmux_mod.addImport("log", log_mod);

    const panes_mod = b.createModule(.{
        .root_source_file = b.path("lib/ui/render/panes.zig"),
        .target = target,
        .optimize = optimize,
    });

    const regs_viewer_mod = b.createModule(.{
        .root_source_file = b.path("lib/core/RegsViewer.zig"),
        .target = target,
        .optimize = optimize,
    });

    regs_viewer_mod.addImport("log", log_mod);
    regs_viewer_mod.addImport("panes", panes_mod);
    regs_viewer_mod.addImport("term", term_mod);
    regs_viewer_mod.addImport("ansi", ansi_mod);

    const repl_mod = b.createModule(.{
        .root_source_file = b.path("lib/core/REPL.zig"),
        .target = target,
        .optimize = optimize,
    });

    repl_mod.addImport("log", log_mod);

    // Unit tests for mods (must run through build graph so module imports work)
    const tui_tests = b.addTest(.{
        .root_source_file = b.path("lib/ui/tui.zig"),
        .target = target,
        .optimize = optimize,
    });
    tui_tests.root_module.addImport("log", log_mod);
    tui_tests.root_module.addImport("term", term_mod);

    const tui_test_step = b.step("test-tui", "Run Tui unit tests");
    tui_test_step.dependOn(&tui_tests.step);

    const repl_tests = b.addTest(.{
        .root_source_file = b.path("lib/core/REPL.zig"),
        .target = target,
        .optimize = optimize,
    });
    repl_tests.root_module.addImport("log", log_mod);

    const repl_test_step = b.step("test-repl", "Run REPL unit tests");
    repl_test_step.dependOn(&repl_tests.step);

    const regs_view_tests = b.addTest(.{
        .root_source_file = b.path("lib/core/RegsViewer.zig"),
        .target = target,
        .optimize = optimize,
    });
    regs_view_tests.root_module.addImport("log", log_mod);
    regs_view_tests.root_module.addImport("panes", panes_mod);
    regs_view_tests.root_module.addImport("term", term_mod);
    regs_view_tests.root_module.addImport("ansi", ansi_mod);

    const regs_view_step = b.step("test-regs-view", "Run Regs View unit tests");
    regs_view_step.dependOn(&regs_view_tests.step);
    // End Unit tests for mods

    const simple = b.addExecutable(.{
        .name = "simple",
        .target = target,
        .optimize = optimize,
    });
    simple.addCSourceFile(.{
        .file = b.path("targets/c/simple.c"),
        .flags = &.{"-g"},
    });
    simple.linkLibC();
    const install_simple = b.addInstallArtifact(simple, .{});
    const simple_step = b.step("simple", "Install the simple executable");
    simple_step.dependOn(&install_simple.step);

    const simple_add = b.addExecutable(.{
        .name = "simple_add",
        .target = target,
        .optimize = optimize,
    });
    simple_add.addCSourceFile(.{
        .file = b.path("targets/c/simple_add_int.c"),
        .flags = &.{"-g"},
    });
    simple_add.linkLibC();
    const install_simple_add = b.addInstallArtifact(simple_add, .{});
    const simple_add_step = b.step("simple_add", "Install the simple_add executable");
    simple_add_step.dependOn(&install_simple_add.step);

    const simple_add_infinite_loop = b.addExecutable(.{
        .name = "simple_add_infinite_loop",
        .target = target,
        .optimize = optimize,
    });
    simple_add_infinite_loop.addCSourceFile(.{
        .file = b.path("targets/c/simple_add_inf_loop.c"),
        .flags = &.{"-g"},
    });
    simple_add_infinite_loop.linkLibC();
    const install_simple_add_infinite_loop = b.addInstallArtifact(simple_add_infinite_loop, .{});
    const simple_add_infinite_loop_step = b.step("simple_add_infinite_loop", "Install the simple_add_infinite_loop executable");
    simple_add_infinite_loop_step.dependOn(&install_simple_add_infinite_loop.step);

    // dipole executables
    const dipole = b.addExecutable(.{
        .name = "dipole",
        .root_source_file = b.path("cmd/dipole/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    dipole.root_module.addImport("args", args_mod);
    dipole.root_module.addImport("ansi", ansi_mod);
    dipole.root_module.addImport("lldbdriver", lldbdriver_mod);
    dipole.root_module.addImport("log", log_mod);
    dipole.root_module.addImport("tui", tui_mod);
    dipole.root_module.addImport("tmux", tmux_mod);
    dipole.root_module.addImport("panes", panes_mod);
    dipole.root_module.addImport("term", term_mod);
    dipole.root_module.addImport("regsview", regs_viewer_mod);
    dipole.root_module.addImport("repl", repl_mod);

    const install_dipole = b.addInstallArtifact(dipole, .{});
    const dipole_step = b.step("dipole", "Install the dipole executable");
    dipole_step.dependOn(&install_dipole.step);

    //*** simple binary to view regs file and appear in right pane of a dipole tmux session
    const dipole_regsview = b.addExecutable(.{
        .name = "dipole-regsview",
        .root_source_file = b.path("cmd/dipole-regsview/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    dipole_regsview.root_module.addImport("regsview", regs_viewer_mod);

    const install_dipole_regsview = b.addInstallArtifact(dipole_regsview, .{});
    const dipole_regsview_step = b.step("dipole-regsview", "Install the dipole-regsview helper");
    dipole_regsview_step.dependOn(&install_dipole_regsview.step);

    //***

    // *** smoke test --no-tmux trying to catch regressions on a simple dipole session
    const smoke_simple = b.addExecutable(.{
        .name = "smoke_simple",
        .root_source_file = b.path("tests/smoke_simple.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_smoke = b.addRunArtifact(smoke_simple);
    run_smoke.addArg(b.getInstallPath(.bin, "dipole"));
    run_smoke.addArg(b.getInstallPath(.bin, "simple"));
    run_smoke.step.dependOn(&install_dipole.step);
    run_smoke.step.dependOn(&install_simple.step);

    const smoke_step = b.step("smoke", "Run Dipole smoke test (run --no-tmux simple)");
    smoke_step.dependOn(&run_smoke.step);
    // *** end smoke test

    const exp_0_4 = b.addExecutable(.{
        .name = "exp-0.4-trace-step",
        .root_source_file = b.path("exp/0.4-trace-step/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exp_0_4.root_module.addImport("trace", trace_mod);

    const install_exp_0_4 = b.addInstallArtifact(exp_0_4, .{});

    const build_exp_0_4_step = b.step("exp-0-4-trace-step", "Build experiment 0.4 (single-step trace)");
    build_exp_0_4_step.dependOn(&install_exp_0_4.step);

    const exp_0_5 = b.addExecutable(.{
        .name = "exp-0.5-trace-n-step",
        .root_source_file = b.path("exp/0.5-trace-n-step/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exp_0_5.root_module.addImport("trace", trace_mod);

    const install_exp_0_5 = b.addInstallArtifact(exp_0_5, .{});

    const build_exp_0_5_n_step = b.step("exp-0-5-trace-n-step", "Build experiment 0.5 (mutli-step trace)");
    build_exp_0_5_n_step.dependOn(&install_exp_0_5.step);

    const exp_0_6 = b.addExecutable(.{
        .name = "exp-0.6-pty-lldb-interactive",
        .root_source_file = b.path("exp/0.6-pty-lldb-interactive/exp0_6.zig"),
        .target = target,
        .optimize = optimize,
    });

    const install_exp_0_6 = b.addInstallArtifact(exp_0_6, .{});

    const build_exp_0_6_pty_lldb_interactive = b.step("exp-0-6-pty-lldb-interactive", "Build experiment 0.6 (pty-lldb-interactive)");
    build_exp_0_6_pty_lldb_interactive.dependOn(&install_exp_0_6.step);

    const exp_0_7 = b.addExecutable(.{
        .name = "exp-0.7-dipole-repl",
        .root_source_file = b.path("exp/0.7-lldb-driver-api/exp0_7.zig"),
        .target = target,
        .optimize = optimize,
    });

    exp_0_7.root_module.addImport("lib", lldbdriver_mod);

    const install_exp_0_7 = b.addInstallArtifact(exp_0_7, .{});

    const build_exp_0_7_dipole_repl = b.step("exp-0-7-dipole-repl-interactive", "Build experiment 0.7 (dipole-repl-interactive)");
    build_exp_0_7_dipole_repl.dependOn(&install_exp_0_7.step);

    // wire installs into the default install step so `zig build` produces zig-out
    const install = b.getInstallStep();
    // simple C programs
    install.dependOn(&install_simple.step);
    install.dependOn(&install_simple_add.step);
    install.dependOn(&install_simple_add_infinite_loop.step);

    // main dipole executable
    install.dependOn(&install_dipole.step);

    //dipole-regsview helper
    install.dependOn(&install_dipole_regsview.step);

    // experiment executables
    install.dependOn(&install_exp_0_4.step);
    install.dependOn(&install_exp_0_5.step);
    install.dependOn(&install_exp_0_6.step);
    install.dependOn(&install_exp_0_7.step);

    _ = try addSimpleProgram(b, "exit_0_c", "targets/c/exit_0.c", true, target, optimize);
    _ = try addSimpleProgram(b, "exit_42_c", "targets/c/exit_42.c", true, target, optimize);
    _ = try addSimpleProgram(b, "exit_0_zig", "targets/zig/exit_0.zig", false, target, optimize);
    _ = try addSimpleProgram(b, "exit_42_zig", "targets/zig/exit_42.zig", false, target, optimize);

    _ = try addSimpleProgram(b, "segfault_c", "targets/c/segfault.c", true, target, optimize);
    _ = try addSimpleProgram(b, "segfault_zig", "targets/zig/segfault.zig", false, target, optimize);

    _ = try addSimpleProgram(b, "stdout_no_newline_c", "targets/c/stdout_no_newline.c", true, target, optimize);
    _ = try addSimpleProgram(b, "stdout_newline_c", "targets/c/stdout_newline.c", true, target, optimize);
    _ = try addSimpleProgram(b, "stdout_flush_c", "targets/c/stdout_flush.c", true, target, optimize);
    _ = try addSimpleProgram(b, "stdout_no_newline_zig", "targets/zig/stdout_no_newline.zig", false, target, optimize);
    _ = try addSimpleProgram(b, "stdout_newline_zig", "targets/zig/stdout_newline.zig", false, target, optimize);
    _ = try addSimpleProgram(b, "stdout_flush_zig", "targets/zig/stdout_flush.zig", false, target, optimize);
}
